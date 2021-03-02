FROM python:alpine3.7
WORKDIR /api
ADD api.py /api
RUN pip install flask
EXPOSE 5000
ENTRYPOINT [ "python" ]
CMD [ "api.py" ]
