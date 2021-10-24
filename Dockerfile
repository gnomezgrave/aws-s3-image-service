FROM public.ecr.aws/lambda/python:3.8

COPY requirements.txt  .
RUN  pip3 install --upgrade pip
RUN  pip3 install -r requirements.txt

CMD [ "app.handler" ]