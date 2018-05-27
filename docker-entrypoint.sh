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
python manage.py makemigrations
python manage.py showmigrations
python manage.py migrate
python manage.py collectstatic --noinput
uwsgi --static-map /static/=static/ \\
    --static-map /media/=media/ \\
    --http-auto-chunked \\
    --http-keepalive \\
    uwsgi.ini
EOF
    chmod +x /code/$PROJECT_NAME/run_uwsgi.sh
}

### generate Dockerfile file ###
_generate_dockerfile() {
    cat > /code/$PROJECT_NAME/Dockerfile << EOF
FROM python:3.6
MAINTAINER Michael J. Stealey <mjstealey@gmail.com>

RUN apt-get update && apt-get install -y \
    postgresql-client \
  && pip install virtualenv \
  && mkdir /code/

WORKDIR /code
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

virtualenv -p /usr/local/bin/python venv
source venv/bin/activate
venv/bin/pip install --upgrade pip
venv/bin/pip install -r requirements.txt

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
    volumes:
      - .:/code
      - ./static:/code/static
      - ./media:/code/media
EOF
}

# populate settings directory
_generate_settings() {
    local SETTINGS_DIR=/code/$PROJECT_NAME/$PROJECT_NAME/settings
    local SETTINGS_PY=/code/$PROJECT_NAME/$PROJECT_NAME/settings.py
    mkdir -p $SETTINGS_DIR
    # generate __init__.py
    cat > $SETTINGS_DIR/__init__.py << EOF
from importlib import import_module

from .applications import *
from .config import *
from .main import *
from .logging import *
from .auth import *
from .api import *
from .tasks import *
EOF
    # generate api.py
    touch $SETTINGS_DIR/api.py
    # generate applications.py
    cat > $SETTINGS_DIR/applications.py <<EOF
import os

# Application definition

EOF
    sed -n -e '/^INSTALLED_APPS/,/^]/p' $SETTINGS_PY >> $SETTINGS_DIR/applications.py
    cat >> $SETTINGS_DIR/applications.py <<EOF

THIRD_PARTY_APPS = []

INSTALLED_APPS += THIRD_PARTY_APPS
EOF
    sed -i -e '/^INSTALLED_APPS/,/^]/d' $SETTINGS_PY
    sed -i -e '/^# Application definition/d' $SETTINGS_PY
    # generate auth.py
    touch $SETTINGS_DIR/auth.py
    # generate config.py
    cat > $SETTINGS_DIR/config.py << EOF
import os

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = os.getenv('DEBUG', True)

EOF
    sed -n -e '/^# Database/,/^# https:\/\/docs.djangoproject.com/p' $SETTINGS_PY >> $SETTINGS_DIR/config.py
    cat >> $SETTINGS_DIR/config.py << EOF

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
    sed -i -e '/^# Database/,/^# https:\/\/docs.djangoproject.com/d' $SETTINGS_PY
    sed -i -e '/^DATABASES/,/^}/d' $SETTINGS_PY
    # generate logging.py
    cat > $SETTINGS_DIR/logging.py << EOF
import os

# Default Django logging is WARNINGS+ to console
# so visible via docker-compose logs uwsgi
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
        },
    },
    'loggers': {
        'django': {
            'handlers': ['console'],
            'level': os.getenv('DJANGO_LOG_LEVEL', 'WARNING'),
        },
    },
}
EOF
    # generate secrets.py
    cat > $SETTINGS_DIR/dummy_secrets.py << EOF
# This file, dummy_secrets, provides an example of how to configure
# sregistry with your authentication secrets. Copy it to secrets.py and
# configure the settings you need.

# Secret Key
# You must uncomment, and set SECRET_KEY to a secure random value
# e.g. https://djskgen.herokuapp.com/

#SECRET_KEY = 'xxxxxxxxxxxxxxxxxx'

EOF
    cat > $SETTINGS_DIR/secrets.py << EOF
# This file, dummy_secrets, provides an example of how to configure
# sregistry with your authentication secrets. Copy it to secrets.py and
# configure the settings you need.

# Secret Key
# You must uncomment, and set SECRET_KEY to a secure random value
# e.g. https://djskgen.herokuapp.com/

EOF
    sed -n -e '0,/^# SECURITY WARNING/{//p;}' $SETTINGS_PY >> $SETTINGS_DIR/secrets.py
    sed -n -e '/^SECRET_KEY/p' $SETTINGS_PY >> $SETTINGS_DIR/secrets.py
    sed -i -e '0,/^# SECURITY WARNING/{//d;}' $SETTINGS_PY
    sed -i -e '/^SECRET_KEY/d' $SETTINGS_PY
    # generate tasks.py
    touch $SETTINGS_DIR/tasks.py
    # generate main.py
    mv $SETTINGS_PY $SETTINGS_DIR/main.py
    sed -i '/import os/a from dotenv import load_dotenv\nload_dotenv(\x27'${PROJECT_NAME}'\x2F.env\x27)' $SETTINGS_DIR/main.py
     sed -i '/^BASE_DIR/c\BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))' $SETTINGS_DIR/main.py
    sed -i '/^# SECURITY WARNING/d' $SETTINGS_DIR/main.py
    sed -i '/^DEBUG/d' $SETTINGS_DIR/main.py
    sed -i 's/ALLOWED_HOSTS = \[\]/ALLOWED_HOSTS = ["*"]/' $SETTINGS_DIR/main.py
    cat >> $SETTINGS_DIR/main.py << EOF
STATIC_ROOT = os.path.join(BASE_DIR, 'static')
MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

try:
    from .secrets import *
except ImportError:
    pass
EOF
}

### main ###
if [ ! -f /code/requirements.txt ]; then
    cp /requirements.txt /code/requirements.txt
    RM_REQTS_FILE=true
else
    RM_REQTS_FILE=false
fi

pip install virtualenv
virtualenv -p /usr/local/bin/python /venv
source /venv/bin/activate
/venv/bin/pip install --upgrade pip
/venv/bin/pip install -r requirements.txt

/venv/bin/django-admin startproject $PROJECT_NAME
/venv/bin/pip freeze  > /code/$PROJECT_NAME/requirements.txt

_generate_env
source /code/$PROJECT_NAME/$PROJECT_NAME/.env

mkdir -p /code/$PROJECT_NAME/apps /code/$PROJECT_NAME/plugins
touch /code/$PROJECT_NAME/plugins/__init__.py
_generate_settings
_generate_uwsgi_ini
_generate_run_uwsgi_sh
_generate_dockerfile
_generate_docker_entrypoint_sh
_generate_docker_compose_yml

# clean up 
if $RM_REQTS_FILE; then
    rm -f /code/requirements.txt
fi

exit 0;
