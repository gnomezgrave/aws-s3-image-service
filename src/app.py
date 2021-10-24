import os
import sys
import json
import logging

import boto3
import base64
from PIL import Image
from io import BytesIO

client = boto3.client('s3')

IMAGES_BUCKET = os.environ['IMAGES_BUCKET']
IMAGES_PREFIX = os.environ['IMAGES_PREFIX']
# To restrict the size of the response to comply to AWS limitations.
BASE_WIDTH = int(os.environ.get("MAX_IMAGE_WIDTH", 2000))

logger = logging.getLogger(__name__)
logger.setLevel(os.environ.get("LOG_LEVEL", "DEBUG"))


def _resize(binary_image):
    image = Image.open(BytesIO(binary_image))

    # Return the original image if it's already smaller
    if image.width < BASE_WIDTH:
        return binary_image

    # Resize the image maintaining the aspect ratio
    w_percent = (BASE_WIDTH / float(image.width))
    h_size = int((float(image.height) * float(w_percent)))
    resized_image = image.resize((BASE_WIDTH, h_size), Image.NEAREST)
    image.close()

    img_byte_arr = BytesIO()
    resized_image.save(img_byte_arr, format='JPEG')
    resized_image.close()

    return img_byte_arr.getvalue()


def handler(event, context):
    # 'path': '/100100040.jpeg' or
    # 'path': '/images/new/uploads/100100040.jpeg'
    logger.debug(f"event: {event}, context: {context}")

    path = event.get('path')

    if not path:
        logger.debug("No path is provided")
        return {
            'statusCode': 400,
            'body': json.dumps('No path is provided!')
        }
    # Removing any spaces and/or slash in the beginning
    path = path.strip().lstrip("/")

    # Insert the bucket prefix for the path generation.
    url_path = f"{IMAGES_PREFIX}/{path}"
    logger.debug(f"URL path: {url_path}")

    try:
        response = client.get_object(
            Bucket=IMAGES_BUCKET,
            Key=url_path
        )

        image = response['Body'].read()
        image = _resize(image)

        image_data = base64.b64encode(image).decode('utf-8')

        logger.debug(f"Image Size: {len(image_data)}")
        logger.debug(f"Image Size Bytes: {sys.getsizeof(image_data)}")

        return {
            'headers': {"Content-Type": "image/jpeg"},
            'statusCode': 200,
            'body': image_data,
            'isBase64Encoded': True
        }

    except Exception as e:
        logger.debug(f"Exception: {e}", exc_info=True)
        logger.debug(f"No such key: {url_path}")
        return {
            'statusCode': 404,
            'body': json.dumps(f'Invalid image path: {path}')
        }
