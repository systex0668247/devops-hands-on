FROM python:alpine

COPY . /app
WORKDIR /app

RUN pip install -r requirements.txt

VOLUME /app/logs

EXPOSE 5000

ENTRYPOINT ["python"]
CMD ["replace.py"]

