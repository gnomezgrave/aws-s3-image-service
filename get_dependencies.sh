CONTAINER_NAME="lambda_container"

remove_container()
{
  CONTAINER_ID=$(docker container ls -qf name=$CONTAINER_NAME);
  if [[ ! -z "$CONTAINER_ID" ]]
  then
    echo "Removing container: $CONTAINER_NAME=$CONTAINER_ID";
    docker container rm -f $CONTAINER_ID > /dev/null;
  else
    echo "No container to remove. Continuing...";
  fi
}

docker build -t lambda_image -f Dockerfile .;
remove_container;
echo "Running container for Lambda dependencies";
docker run --name lambda_container -v $(pwd)/_build:/mnt/build -itd lambda_image /bin/bash;
echo "Copying dependencies to the local folder";
docker exec -it lambda_container /bin/bash -c 'cp -R /var/lang/lib/python3.8/site-packages/* /mnt/build/';
remove_container;