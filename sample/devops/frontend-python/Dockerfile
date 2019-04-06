FROM python:slim-stretch

RUN mkdir -p /python
COPY requirements.txt /python/requirements.txt
RUN pip install -r /python/requirements.txt

COPY app /python/app

EXPOSE 80

CMD ["/usr/local/bin/python3", "/python/app/app.py"]
