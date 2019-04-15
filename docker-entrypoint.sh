#!/usr/bin/env bash
set -e

### generate python .env file ###
_generate_python_dot_env() {
    cat > /code/${PROJECT_NAME}/${PROJECT_NAME}/env.template <<EOF
# Settings for environment. Notes:
#
#  - Since these are bash-like settings, there should be no space between the
#    variable name and the value (ie, "A=B", not "A = B")
#  - Boolean values should be all lowercase (ie, "A=false", not "A=False")

# Debug
export DEBUG=true

# PostgreSQL database - default values should not be used in production
export PGDATA=/var/lib/postgresql/data
export POSTGRES_DB=postgres
export POSTGRES_HOST=database
export POSTGRES_PASSWORD=postgres
export POSTGRES_PORT=5432
export POSTGRES_USER=postgres

# uWSGI service in Django
export UWSGI_GID=${UWSGI_GID}
export UWSGI_UID=${UWSGI_UID}
EOF
    cp /code/${PROJECT_NAME}/${PROJECT_NAME}/env.template /code/${PROJECT_NAME}/${PROJECT_NAME}/.env
}

### generate docker-compose .env file ###
_generate_compose_dot_env() {
    cat > /code/${PROJECT_NAME}/env.template <<EOF
# docker-compose environment file
#
# When you set the same environment variable in multiple files,
# here’s the priority used by Compose to choose which value to use:
#
#  1. Compose file
#  2. Shell environment variables
#  3. Environment file
#  4. Dockerfile
#  5. Variable is not defined

# PostgreSQL database - default values should not be used in production
PGDATA=/var/lib/postgresql/data
POSTGRES_DB=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_PORT=5432
POSTGRES_USER=postgres

# uWSGI services in Django
UWSGI_GID=${UWSGI_GID}
UWSGI_UID=${UWSGI_UID}
EOF
    if $WITH_NGINX; then
        cat >> /code/${PROJECT_NAME}/env.template <<EOF

# Nginx configuration
NGINX_DEFAULT_CONF=./nginx/default.conf
NGINX_SSL_CERT=./ssl/ssl_dev.crt
NGINX_SSL_KEY=./ssl/ssl_dev.key
EOF
    fi
    cp /code/${PROJECT_NAME}/env.template /code/${PROJECT_NAME}/.env
}

### generate uwsgi.ini file ###
_generate_uwsgi_ini() {
    cat > /code/${PROJECT_NAME}/${PROJECT_NAME}_uwsgi.ini << EOF
[uwsgi]
; http://uwsgi-docs.readthedocs.io/en/latest/Options.html
; the base directory before apps loading (full path)
chdir               = ./
; load Django's WSGI file/module
module              = ${PROJECT_NAME}.wsgi
; set PYTHONHOME/virtualenv (full path)
;virtualenv          = ./venv ;;; now set in run_uwsgi script
; enable master process
master              = true
; spawn the specified number of workers/processes
workers             = 1
; run each worker in prethreaded mode with the specified number of threads
threads             = 1
; use protocol uwsgi over TCP socket (use if UNIX file socket is not an option)
;socket              = :8000
EOF
    if $WITH_NGINX; then
        cat >> /code/${PROJECT_NAME}/${PROJECT_NAME}_uwsgi.ini << EOF
; add an http router/server on the specified address **port**
;http                = :8000
; map mountpoint to static directory (or file) **port**
;static-map          = /static/=static/
;static-map          = /media/=media/
; bind to the specified UNIX/TCP socket using uwsgi protocol (full path) **socket**
uwsgi-socket        = ./django.sock
; ... with appropriate permissions - may be needed **socket**
chmod-socket        = 666
EOF
    else
        cat >> /code/${PROJECT_NAME}/${PROJECT_NAME}_uwsgi.ini << EOF
; add an http router/server on the specified address **port**
http                = :8000
; map mountpoint to static directory (or file) **port**
static-map          = /static/=static/
static-map          = /media/=media/
; bind to the specified UNIX/TCP socket using uwsgi protocol (full path) **socket**
;uwsgi-socket        = ./${PROJECT_NAME}.sock
; ... with appropriate permissions - may be needed **socket**
;chmod-socket        = 666
EOF
    fi
    cat >> /code/${PROJECT_NAME}/${PROJECT_NAME}_uwsgi.ini << EOF
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
    cat > /code/${PROJECT_NAME}/run_uwsgi.sh << EOF
#!/usr/bin/env bash

APPS_LIST=(
  "admin"
  "auth"
  "contenttypes"
  "sessions"
  "users"
)

for app in "\${APPS_LIST[@]}";do
    python manage.py makemigrations \$app
done
python manage.py makemigrations
python manage.py showmigrations
python manage.py migrate
python manage.py collectstatic --noinput

if [[ "\${USE_DOT_VENV}" -eq 1 ]]; then
    uwsgi --uid \${UWSGI_UID:-${UWSGI_UID}} --gid \${UWSGI_GID:-${UWSGI_GID}}  --virtualenv ./.venv --ini ${PROJECT_NAME}_uwsgi.ini
else
    uwsgi --uid \${UWSGI_UID:-${UWSGI_UID}} --gid \${UWSGI_GID:-${UWSGI_GID}}  --virtualenv ./venv --ini ${PROJECT_NAME}_uwsgi.ini
fi
EOF
    chmod +x /code/${PROJECT_NAME}/run_uwsgi.sh
}

### generate .gitignore file ###
_generate_dot_gitignore() {
    cat > /code/${PROJECT_NAME}/.gitignore << EOF
*.egg
*.egg-info
*.py[cod]
*.sock
.coverage
.DS_Store
.idea
.pytest_cache
.venv
/.env
/${PROJECT_NAME}/.env
/${PROJECT_NAME}/secrets.py
/media
/nginx/default.conf
/pg_data
/static
/venv
__pycache__
EOF
}

### generate Dockerfile file ###
_generate_dockerfile() {
    cat > /code/${PROJECT_NAME}/Dockerfile << "EOF"
FROM python:3
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
    cat > /code/${PROJECT_NAME}/docker-entrypoint.sh << EOF
#!/usr/bin/env bash
set -e

virtualenv -p /usr/local/bin/python .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

chown -R \${UWSGI_UID:-1000}:\${UWSGI_GID:-1000} .venv

until [ \$(pg_isready -h database -q)\$? -eq 0 ]; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 1
done

>&2 echo "Postgres is up - continuing"

USE_DOT_VENV=1 ./run_uwsgi.sh

exec "\$@"
EOF
    chmod +x /code/${PROJECT_NAME}/docker-entrypoint.sh
}

### generate docker-compose.yml file ###
_generate_docker_compose_yml() {
    cat > /code/${PROJECT_NAME}/docker-compose.yml << EOF
version: '3.6'
services:

  database:
    image: postgres:11
    container_name: database
    ports:
      - \${POSTGRES_PORT:-5432}:5432
    volumes:
      - ./pg_data/data:\${PGDATA:-/var/lib/postgresql/data}
      - ./pg_data/logs:\${POSTGRES_INITDB_WALDIR:-/var/log/postgresql}
    environment:
      - POSTGRES_USER=\${POSTGRES_USER:-postgres}
      - POSTGRES_PASSWORD=\${POSTGRES_PASSWORD:-postgres}
      - PGDATA=\${PGDATA:-/var/lib/postgresql/data}
      - POSTGRES_DB=postgres

  django:
    build:
      context: ./
      dockerfile: Dockerfile
    image: django
    container_name: django
    depends_on:
      - database
    ports:
      - 8000:8000
    volumes:
      - .:/code
      - ./static:/code/static
      - ./media:/code/media
    environment:
      - UWSGI_UID=\${UWSGI_UID:-${UWSGI_UID}}
      - UWSGI_GID=\${UWSGI_GID:-${UWSGI_GID}}

EOF
    if $WITH_NGINX; then
        cat >> /code/${PROJECT_NAME}/docker-compose.yml << EOF

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
      - \${NGINX_DEFAULT_CONF:-./nginx/default.conf}:/etc/nginx/conf.d/default.conf
      - \${NGINX_SSL_CERT:-./ssl/ssl_dev.crt}:/etc/ssl/SSL.crt  # SSL certificate
      - \${NGINX_SSL_KEY:-./ssl/ssl_dev.key}:/etc/ssl/SSL.key   # SSL key
EOF
    fi
}

### populate nginx directory with conf files
_generate_nginx_conf() {
    if [[ ! -d /code/${PROJECT_NAME}/nginx ]]; then
        mkdir -p /code/${PROJECT_NAME}/nginx
    fi
    cat > /code/${PROJECT_NAME}/nginx/default.conf.template << EOF
# the upstream component nginx needs to connect to
upstream django {
    server unix:///code/django.sock; # UNIX file socket
    # Defaulting to macOS equivalent of docker0 network for TCP socket
    #server docker.for.mac.localhost:8000; # TCP socket
}

# configuration of the server
server {
    # the port your site will be served on
    listen      80;
    # the domain name it will serve for
    server_name \$host:8080;
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
    cp /code/${PROJECT_NAME}/nginx/default.conf.template /code/${PROJECT_NAME}/nginx/default.conf
    cat > /code/${PROJECT_NAME}/nginx/default_ssl.conf.template << EOF
# the upstream component nginx needs to connect to
upstream django {
    server unix:///code/django.sock; # UNIX file socket
    # Defaulting to macOS equivalent of docker0 network for TCP socket
    #server host.docker.internal:8000; # TCP socket
}

server {
    listen 80;
    return 301 https://\$host:8443\$request_uri;
}

server {
    listen   443 ssl default_server;
    # the domain name it will serve for
    server_name \$host:8443; # substitute your machine's IP address or FQDN

    # If they come here using HTTP, bounce them to the correct scheme
    error_page 497 https://\$server_name\$request_uri;
    # Or if you're on the default port 443, then this should work too
    # error_page 497 https://;

    ssl_certificate /etc/ssl/SSL.crt;
    ssl_certificate_key /etc/ssl/SSL.key;

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
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Host \$http_host;
        proxy_redirect off;

        uwsgi_pass  django;
        include     /code/uwsgi_params; # the uwsgi_params file
    }
}
EOF
    cat > /code/${PROJECT_NAME}/uwsgi_params << EOF

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

_generate_secrets_files() {
    local SETTINGS_DIR=$1
    local SETTINGS_PY=$SETTINGS_DIR/settings.py
    # generate secrets.py
    cat > ${SETTINGS_DIR}/secrets.py.template << EOF
# This file, dummy_secrets, provides an example of how to configure
# sregistry with your authentication secrets. Copy it to secrets.py and
# configure the settings you need.

# Secret Key
# You must uncomment, and set SECRET_KEY to a secure random value
# e.g. https://djskgen.herokuapp.com/

#SECRET_KEY = 'xxxxxxxxxxxxxxxxxx'

EOF
    cat > ${SETTINGS_DIR}/secrets.py << EOF
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
}

### create secrets file from settings.py
_generate_settings() {
    local SETTINGS_PY=/code/${PROJECT_NAME}/${PROJECT_NAME}/settings.py
    # secrets files
    _generate_secrets_files $(dirname $SETTINGS_PY)
    # add .env
    sed -i '/import os/a from dotenv import load_dotenv\nload_dotenv(\x27'${PROJECT_NAME}'\x2F.env\x27)' $SETTINGS_PY
    # set debug
    sed -i 's/^DEBUG.*/DEBUG = os.getenv(\x27DEBUG\x27, True)/' $SETTINGS_PY
    # set allowed hosts
    sed -i 's/^ALLOWED_HOSTS.*/ALLOWED_HOSTS = ["*"]/' $SETTINGS_PY
    # import secrets files
    cat >> $SETTINGS_PY << EOF
STATIC_ROOT = os.path.join(BASE_DIR, 'static')
MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

# pytest-django as the test runner
# https://pytest-django.readthedocs.io/en/latest/faq.html
TEST_RUNNER = '${PROJECT_NAME}.runner.PytestTestRunner'

try:
    from .secrets import *
except ImportError:
    pass
EOF
    # set database
    sed -n -i '/^DATABASES/{:a;N;/\n}/!ba;N;s/.*\n/ \
DATABASES = { \
    \x27default\x27: { \
        \x27ENGINE\x27: \x27django.db.backends.postgresql\x27, \
        \x27NAME\x27: os.getenv(\x27POSTGRES_DB\x27, \x27postgres\x27), \
        \x27USER\x27: os.getenv(\x27POSTGRES_USER\x27, \x27postgres\x27), \
        \x27PASSWORD\x27: os.getenv(\x27POSTGRES_PASSWORD\x27, \x27postgres\x27), \
        \x27HOST\x27: os.getenv(\x27POSTGRES_HOST\x27, \x27127.0.0.1\x27), \
        \x27PORT\x27: os.getenv(\x27POSTGRES_PORT\x27, \x275432\x27), \
    } \
}\n/};p' $SETTINGS_PY
}

### generate self-signed SSL certificates
_generate_self_signed_ssl_certs() {
    if [[ ! -d /code/${PROJECT_NAME}/ssl ]]; then
        mkdir -p /code/${PROJECT_NAME}/ssl
    fi
    if [[ ! -f /code/${PROJECT_NAME}/ssl/ssl_dev.crt ]]; then
    cd /code/${PROJECT_NAME}/ssl
        openssl req -newkey rsa:4096 -days 3650 -nodes -x509 \
            -subj "/C=US/ST=North Carolina/L=Chapel Hill/O=Local/OU=Development/CN=local.dev/emailAddress=email@local.dev" \
            -keyout ssl_dev.key \
            -out ssl_dev.crt
    chmod 0600 ssl_dev.key
    cd -
    fi
    cp /code/${PROJECT_NAME}/nginx/default_ssl.conf.template /code/${PROJECT_NAME}/nginx/default.conf
}

### generate runner.py, pytest.ini and conftest.py for use with pytest
_generate_pytest_files() {
    cat > /code/${PROJECT_NAME}/${PROJECT_NAME}/runner.py <<EOF
"""
./manage.py test <django args> -- <pytest args>
"""


class PytestTestRunner(object):
    """Runs pytest to discover and run tests."""

    def __init__(self, verbosity=1, failfast=False, keepdb=False, **kwargs):
        self.verbosity = verbosity
        self.failfast = failfast
        self.keepdb = keepdb

    def run_tests(self, test_labels):
        """Run pytest and return the exitcode.

        It translates some of Django's test command option to pytest's.
        """
        import pytest

        argv = []
        if self.verbosity == 0:
            argv.append('--quiet')
        if self.verbosity == 2:
            argv.append('--verbose')
        if self.verbosity == 3:
            argv.append('-vv')
        if self.failfast:
            argv.append('--exitfirst')
        if self.keepdb:
            argv.append('--reuse-db')

        argv.extend(test_labels)
        return pytest.main(argv)

EOF
    cat > /code/${PROJECT_NAME}/pytest.ini <<EOF
[pytest]
DJANGO_SETTINGS_MODULE =
    ${PROJECT_NAME}.settings
python_files =
    *.py
norecursedirs =
    .git
    .idea
    _build tmp*
filterwarnings =
    ignore::DeprecationWarning

EOF
    cat > /code/${PROJECT_NAME}/conftest.py <<EOF
import sys

collect_ignore = [
    ".venv/*",
    "venv/*",
    "pg_data/*"
]


@pytest.fixture(autouse=True)
def enable_db_access_for_all_tests(db):
    pass

EOF
}

# generate custom user model
_generate_custom_user() {
    cd /code/${PROJECT_NAME}
    python manage.py startapp users
    cd -
    sed -i "/'django.contrib.staticfiles',/a\    'users.apps.UsersConfig'," \
        /code/${PROJECT_NAME}/${PROJECT_NAME}/settings.py
    cat >> /code/${PROJECT_NAME}/${PROJECT_NAME}/settings.py <<EOF

AUTH_USER_MODEL = 'users.CustomUser'
EOF
    cat > /code/${PROJECT_NAME}/users/models.py <<EOF
from django.contrib.auth.models import AbstractUser
from django.db import models


class CustomUser(AbstractUser):
    pass

EOF
    cat > /code/${PROJECT_NAME}/users/forms.py <<EOF
from django import forms
from django.contrib.auth.forms import UserCreationForm, UserChangeForm
from .models import CustomUser

class CustomUserCreationForm(UserCreationForm):

    class Meta(UserCreationForm):
        model = CustomUser
        fields = ('username', 'email')

class CustomUserChangeForm(UserChangeForm):

    class Meta:
        model = CustomUser
        fields = ('username', 'email')

EOF
    cat > /code/${PROJECT_NAME}/users/admin.py <<EOF
from django.contrib import admin
from django.contrib.auth import get_user_model
from django.contrib.auth.admin import UserAdmin

from .forms import CustomUserCreationForm, CustomUserChangeForm
from .models import CustomUser

class CustomUserAdmin(UserAdmin):
    add_form = CustomUserCreationForm
    form = CustomUserChangeForm
    model = CustomUser
    list_display = ['email', 'username',]

admin.site.register(CustomUser, CustomUserAdmin)

EOF
}

### main ###

OPTIONS=nso:z:u:g:h
LONGOPTIONS=nginx,ssl-certs,owner-uid:,owner-gid:,uwsgi-uid:,uwsgi-gid:,help
WITH_NGINX=false
WITH_SSL=false
SPLIT_SETTINGS=false
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
        -s|--ssl-certs)
            echo "### Generate with SSL self-signed Certificates ###"
            WITH_SSL=true
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

Usage: django-startproject-docker [-nsh] [-o owner_uid] [-z owner_gid] [-u uwsgi_uid] [-g uwsgi_gid]
         -n|--nginx          = Include Nginx service definition files with build output
         -s|--ssl-certs      = Generate self-signed SSL certificates and configure Nginx to use https
         -h|--help           = Help/Usage output
         -o|--owner-uid      = UID to attribute output file ownership to (default=1000)
         -z|--owner-gid      = GID to attribute output file ownership to (default=1000)
         -u|--uwsgi-uid      = UID to run the uwsgi service as (default=1000)
         -g|--uwsgi-gid      = GID to run the uwsgi service as (default=1000)

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

# check for requirements file
if [[ ! -f /code/requirements.txt ]]; then
    cp /requirements.txt /code/requirements.txt
    RM_REQTS_FILE=true
else
    RM_REQTS_FILE=false
fi

# setup virtual environment
pip install virtualenv
virtualenv -p /usr/local/bin/python /venv
source /venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# create Django project as PROJECT_NAME
django-admin startproject ${PROJECT_NAME}
pip freeze  > /code/${PROJECT_NAME}/requirements.txt

# create python .env template and initial file
_generate_python_dot_env
source /code/${PROJECT_NAME}/${PROJECT_NAME}/.env

# create directories for django and postgres
mkdir -p /code/${PROJECT_NAME}/static \
    /code/${PROJECT_NAME}/media \
    /code/${PROJECT_NAME}/pg_data/data \
    /code/${PROJECT_NAME}/pg_data/logs

# create other Django related files
_generate_settings
_generate_pytest_files
_generate_uwsgi_ini
_generate_dot_gitignore
_generate_run_uwsgi_sh

# create custom user model
_generate_custom_user

# create Nginx related files
if $WITH_NGINX; then
    _generate_nginx_conf
    if $WITH_SSL; then
        mkdir -p /code/${PROJECT_NAME}/ssl
        _generate_self_signed_ssl_certs
    fi
fi

# create docker based files
_generate_dockerfile
_generate_docker_entrypoint_sh
_generate_docker_compose_yml
_generate_compose_dot_env

# set ownership of all files to be that of OWNER_UID:OWNER_GID
chown -R $OWNER_UID:$OWNER_GID /code/${PROJECT_NAME}

# clean up
if $RM_REQTS_FILE; then
    rm -f /code/requirements.txt
fi
while read line; do
  rm -rf $line;
done < <(find /code -type d -name __pycache__)

exit 0;
