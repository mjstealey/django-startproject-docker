FROM python:3
MAINTAINER Michael J. Stealey <mjstealey@gmail.com>

ENV PROJECT_NAME=example_project

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY requirements.txt /requirements.txt

VOLUME ["/code"]
WORKDIR /code

ENTRYPOINT ["/docker-entrypoint.sh"]
