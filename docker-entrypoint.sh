#!/usr/bin/env bash
set -e

### generate .env file ###
_generate_env() {
    cat > /code/$PROJECT_NAME/$PROJECT_NAME/.env <<EOF
# Settings for environment. Notes:
#
#  - Since these are bash-like settings, there should be no space between the
#    variable name and the value (ie, "A=B", not "A = B")
#  - Boolean values should be all lowercase (ie, "A=false", not "A=False")

# debug
export DEBUG=true

# database PostgreSQL
export POSTGRES_PASSWORD=postgres
export POSTGRES_USER=postgres
export PGDATA=/var/lib/postgresql/data
export POSTGRES_DB=postgres
export POSTGRES_HOST=127.0.0.1
export POSTGRES_PORT=5432
EOF
}

### generate uwsgi.ini file ###
_generate_uwsgi_ini() {
    cat > /code/$PROJECT_NAME/uwsgi.ini << EOF
[uwsgi]
virtualenv = venv
wsgi-file = ${PROJECT_NAME}/wsgi.py
http = :8000
master = 1
workers = 2
threads = 8
lazy-apps = 1
wsgi-env-behavior = holy
post-buffering = true
log-date = true
max-requests = 5000
EOF
}

### generate run_uwsgi.sh file ###
_generate_run_uwsgi_sh() {
    cat > /code/$PROJECT_NAME/run_uwsgi.sh << EOF
#!/usr/bin/env bash

source venv/bin/activate
venv/bin/python manage.py makemigrations
venv/bin/python manage.py migrate
venv/bin/python manage.py collectstatic --noinput
venv/bin/uwsgi --http-auto-chunked --http-keepalive uwsgi.ini
EOF
    chmod +x /code/$PROJECT_NAME/run_uwsgi.sh
}

### generate secrets.py file ###
_generate_secrets_py() {
cat > /code/$PROJECT_NAME/$PROJECT_NAME/secrets.py << EOF
import os

DEBUG = os.getenv('DEBUG', 'True')

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.getenv('POSTGRES_DB', '${POSTGRES_DB}'),
        'USER': os.getenv('POSTGRES_USER', '${POSTGRES_USER}'),
        'PASSWORD': os.getenv('POSTGRES_PASSWORD', '${POSTGRES_PASSWORD}'),
        'HOST': os.getenv('POSTGRES_HOST', '${POSTGRES_HOST}'),
        'PORT': os.getenv('POSTGRES_PORT', '${POSTGRES_PORT}'),
    }
}
EOF
}

### update settings.py file ###
_update_settings_py() {
sed -i '/import os/a from dotenv import load_dotenv\nload_dotenv(\x27'${PROJECT_NAME}'\x2F.env\x27)' /code/$PROJECT_NAME/$PROJECT_NAME/settings.py
sed -i 's/ALLOWED_HOSTS = \[\]/ALLOWED_HOSTS = ["*"]/' /code/$PROJECT_NAME/$PROJECT_NAME/settings.py
    cat >> /code/$PROJECT_NAME/$PROJECT_NAME/settings.py << EOF
STATIC_ROOT = os.path.join(BASE_DIR, 'static')
MEDIA_URL = '/images/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'images')

try:
    from .secrets import *
except ImportError:
    pass
EOF
}

### generate Dockerfile file ###
_generate_dockerfile() {
    cat > /code/$PROJECT_NAME/Dockerfile << EOF
FROM python:3.6
MAINTAINER Michael J. Stealey <mjstealey@gmail.com>

RUN apt-get update && apt-get install -y \\
    postgresql-client

RUN mkdir /code/
COPY . /code/

WORKDIR /code
RUN if [ -d /code/venv ]; then rm -rf /code/venv; fi \\
    && if [ -d /code/static ]; then rm -rf /code/static; fi \\
    && if [ -d /code/media ]; then rm -rf /code/media; fi \\
    && python -m venv venv \\
    && . venv/bin/activate \\
    && venv/bin/pip install --upgrade pip \\
    && venv/bin/pip install -r requirements.txt

VOLUME ["/code"]

ENTRYPOINT ["/code/docker-entrypoint.sh"]
EOF
}

### generate docker-entrypoint.sh file ###
_generate_docker_entrypoint_sh() {
    cat > /code/$PROJECT_NAME/docker-entrypoint.sh << EOF
#!/usr/bin/env bash
set -e

until [ \$(pg_isready -h database -q)\$? -eq 0 ]; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 1
done

>&2 echo "Postgres is up - continuing"

./run_uwsgi.sh

exec "\$@"
EOF
    chmod +x /code/$PROJECT_NAME/docker-entrypoint.sh
}

### generate docker-compose.yml file ###
_generate_docker_compose_yml() {
cat > /code/$PROJECT_NAME/docker-compose.yml << EOF
version: '3.0'
services:

  database:
    image: postgres:10
    container_name: database
    hostname: database
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_USER: ${POSTGRES_USER}
      PGDATA: ${PGDATA}
      POSTGRES_DB: ${POSTGRES_DB}
    ports:
      - 5432:${POSTGRES_PORT}

  django:
    build:
      context: ./
      dockerfile: Dockerfile
    image: django
    container_name: django
    hostname: django
    environment:
      POSTGRES_HOST: database
    ports:
      - 8000:8000
      - 8443:443
      - 8080:80
EOF
}

### main ###
cp /requirements.txt /code/requirements.txt

python -m venv /venv
source /venv/bin/activate
/venv/bin/pip install --upgrade pip
/venv/bin/pip install -r requirements.txt

/venv/bin/django-admin startproject $PROJECT_NAME
/venv/bin/pip freeze  > /code/$PROJECT_NAME/requirements.txt

_generate_env
source /code/$PROJECT_NAME/$PROJECT_NAME/.env

_update_settings_py
_generate_secrets_py
_generate_uwsgi_ini
_generate_run_uwsgi_sh
_generate_dockerfile
_generate_docker_entrypoint_sh
_generate_docker_compose_yml

exit 0;