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
    cat > /code/$PROJECT_NAME/${PROJECT_NAME}_uwsgi.ini << EOF
[uwsgi]
; http://uwsgi-docs.readthedocs.io/en/latest/Options.html
; the base directory before apps loading (full path)
chdir               = /code
; load Django's WSGI file/module
module              = ${PROJECT_NAME}.wsgi
; set PYTHONHOME/virtualenv (full path)
virtualenv          = /code/venv
; enable master process
master              = true
; spawn the specified number of workers/processes
workers             = 1
; run each worker in prethreaded mode with the specified number of threads
threads             = 1
EOF
    if $WITH_NGINX; then
        cat >> /code/$PROJECT_NAME/${PROJECT_NAME}_uwsgi.ini << EOF
; bind to the specified UNIX/TCP socket using uwsgi protocol (full path)
uwsgi-socket        = /code/${PROJECT_NAME}.sock
; ... with appropriate permissions - may be needed
chmod-socket        = 666
EOF
    else
        cat >> /code/$PROJECT_NAME/${PROJECT_NAME}_uwsgi.ini << EOF
; add an http router/server on the specified address
http                = :8000
; map mountpoint to static directory (or file)
static-map          = /static/=static/
static-map          = /media/=media/
EOF
    fi
    cat >> /code/$PROJECT_NAME/${PROJECT_NAME}_uwsgi.ini << EOF
; clear environment on exit
vacuum              = true
; automatically transform output to chunked encoding during HTTP 1.1 keepalive
http-auto-chunked   = true
; HTTP 1.1 keepalive support (non-pipelined) requests
http-keepalive      = true
; load apps in each worker instead of the master
lazy-apps           = true
; strategy for allocating/deallocating the WSGI env
wsgi-env-behavior   = holy
; enable post buffering
post-buffering      = true
; prefix logs with date or a strftime string
log-date            = true
; reload workers after the specified amount of managed requests
max-requests        = 5000
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
uwsgi --uid ${UWSGI_UID} --gid ${UWSGI_GID} --ini ${PROJECT_NAME}_uwsgi.ini
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
    volumes:
      - .:/code
      - ./static:/code/static
      - ./media:/code/media
EOF
    if $WITH_NGINX; then
        cat >> /code/$PROJECT_NAME/docker-compose.yml << EOF

  nginx:
    image: nginx:latest
    container_name: nginx
    ports:
      - 8080:80
      - 8443:443
    volumes:
      - .:/code
      - ./static:/code/static
      - ./media:/code/media
      - ./nginx/${PROJECT_NAME}_nginx.conf:/etc/nginx/conf.d/default.conf
EOF
    fi
}

### populate nginx directory with conf files
_generate_nginx_conf() {
    if [[ ! -d /code/$PROJECT_NAME/nginx ]]; then
        mkdir -p /code/$PROJECT_NAME/nginx
    fi
    cat > /code/$PROJECT_NAME/nginx/${PROJECT_NAME}_nginx.conf << EOF
# ${PROJECT_NAME}_nginx.conf

# the upstream component nginx needs to connect to
upstream django {
    server unix:///code/${PROJECT_NAME}.sock; # for a file socket
}

# configuration of the server
server {
    # the port your site will be served on
    listen      80;
    # the domain name it will serve for
    server_name 127.0.0.1:8080; # substitute your machine's IP address or FQDN
    charset     utf-8;

    # max upload size
    client_max_body_size 75M;   # adjust to taste

    # Django media
    location /media  {
        alias /code/media;  # your Django project's media files - amend as required
    }

    location /static {
        alias /code/static; # your Django project's static files - amend as required
    }

    # Finally, send all non-media requests to the Django server.
    location / {
        uwsgi_pass  django;
        include     /code/uwsgi_params; # the uwsgi_params file you installed
    }
}
EOF
    cat > /code/$PROJECT_NAME/nginx/${PROJECT_NAME}_nginx_ssl.conf << EOF
# ${PROJECT_NAME}_nginx_ssl.conf

# the upstream component nginx needs to connect to
upstream django {
    server unix:///code/${PROJECT_NAME}.sock;
}

server {
    listen 80;
    server_name 127.0.0.1:8080; # substitute your machine's IP address or FQDN
    return 301 https://127.0.0.1:8443\$request_uri; # substitute your machine's IP address or FQDN
}

# configuration of the server
server {
    # the port your site will be served on
    listen      443;

    ssl on;
    ssl_certificate /etc/ssl/SSL.crt;
    ssl_certificate_key /etc/ssl/SSL.key;

    # the domain name it will serve for
    server_name 127.0.0.1:8443; # substitute your machine's IP address or FQDN
    charset     utf-8;

    # max upload size
    client_max_body_size 75M;   # adjust to taste

    # Django media
    location /media  {
        alias /code/media;  # your Django project's media files - amend as required
    }

    location /static {
        alias /code/static; # your Django project's static files - amend as required
    }

    # Finally, send all non-media requests to the Django server.
    location / {
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;  # <-
        proxy_set_header Host \$http_host;
        proxy_redirect off;

        uwsgi_pass  django;
        include     /code/uwsgi_params; # the uwsgi_params file you installed
    }
}
EOF
    cat > /code/$PROJECT_NAME/uwsgi_params << EOF

uwsgi_param  QUERY_STRING       \$query_string;
uwsgi_param  REQUEST_METHOD     \$request_method;
uwsgi_param  CONTENT_TYPE       \$content_type;
uwsgi_param  CONTENT_LENGTH     \$content_length;

uwsgi_param  REQUEST_URI        \$request_uri;
uwsgi_param  PATH_INFO          \$document_uri;
uwsgi_param  DOCUMENT_ROOT      \$document_root;
uwsgi_param  SERVER_PROTOCOL    \$server_protocol;
uwsgi_param  REQUEST_SCHEME     \$scheme;
uwsgi_param  HTTPS              \$https if_not_empty;

uwsgi_param  REMOTE_ADDR        \$remote_addr;
uwsgi_param  REMOTE_PORT        \$remote_port;
uwsgi_param  SERVER_PORT        \$server_port;
uwsgi_param  SERVER_NAME        \$server_name;
EOF
}

### populate settings directory
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
OPTIONS=no:z:u:g:h
LONGOPTIONS=nginx,owner-uid:,owner-gid:,uwsgi-uid:,uwsgi-gid:,help
WITH_NGINX=false
OWNER_UID=1000
OWNER_GID=1000
UWSGI_UID=1000
UWSGI_GID=1000

# -temporarily store output to be able to check for errors
# -e.g. use “--options” parameter by name to activate quoting/enhanced mode
# -pass arguments only via   -- "$@"   to separate them correctly
PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTIONS --name "$0" -- "$@")
if [[ $? -ne 0 ]]; then
    # e.g. $? == 1
    #  then getopt has complained about wrong arguments to stdout
    exit 2
fi
# read getopt’s output this way to handle the quoting right:
eval set -- "$PARSED"

# now enjoy the options in order and nicely split until we see --
while true; do
    case "$1" in
        -n|--nginx)
            echo "### Generate with Nginx ###"
            WITH_NGINX=true
            shift
            ;;
        -o|--owner-uid)
            echo "### Set owner UID = ${2} ###"
            OWNER_UID="$2"
            shift 2
            ;;
        -z|--owner-gid)
            echo "### Set owner UID = ${2} ###"
            OWNER_GID="$2"
            shift 2
            ;;
        -u|--uwsgi-uid)
            echo "### Set uWSGI UID = ${2} ###"
            UWSGI_UID="$2"
            shift 2
            ;;
        -g|--uwsgi-gid)
            echo "### Set uWSGI GID = ${2} ###"
            UWSGI_GID="$2"
            shift 2
            ;;
        -h|--help)
            echo "### Help ###"
            cat >&1 << EOF

Usage: django-startproject-docker [-nh] [-o owner_uid] [-z owner_gid] [-u uwsgi_uid] [-g uwsgi_gid]
         -n|--nginx     = Include Nginx service definition files with build output
         -h|--help      = Help/Usage output
         -o|--owner-uid = Host UID to attribute output file ownership to (default 1000)
         -z|--owner-gid = Host GID to attribute output file ownership to (default 1000)
         -u|--uwsgi-uid = Host UID to run the uwsgi service as (default 1000)
         -g|--uwsgi-gid = Host GID to run the uwsgi service as (default 1000)

EOF
            shift
            exit 0;
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Programming error"
            exit 3
            ;;
    esac
done

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
if $WITH_NGINX; then
    _generate_nginx_conf
fi
_generate_dockerfile
_generate_docker_entrypoint_sh
_generate_docker_compose_yml
chown -R $OWNER_UID:$OWNER_GID /code/$PROJECT_NAME

# clean up 
if $RM_REQTS_FILE; then
    rm -f /code/requirements.txt
fi

exit 0;
