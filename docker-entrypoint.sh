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
    cat > /code/$PROJECT_NAME/uwsgi.ini <<EOF
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
    cat > /code/$PROJECT_NAME/run_uwsgi.sh <<EOF
#!/usr/bin/env bash

source venv/bin/activate
python manage.py makemigrations
python manage.py migrate
python manage.py collectstatic --noinput
uwsgi --static-map /static/=static/ \\
    --static-map /images/=images/ \\
    --http-auto-chunked \\
    --http-keepalive \\
    uwsgi.ini
EOF
    chmod +x /code/$PROJECT_NAME/run_uwsgi.sh
}

### generate secrets.py file ###
_generate_secrets_py() {
cat > /code/$PROJECT_NAME/$PROJECT_NAME/secrets.py <<EOF
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
    cat >> /code/$PROJECT_NAME/$PROJECT_NAME/settings.py <<EOF
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
    cat > /code/$PROJECT_NAME/Dockerfile <<EOF
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
    cat > /code/$PROJECT_NAME/docker-entrypoint.sh <<EOF
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
cat > /code/$PROJECT_NAME/docker-compose.yml <<EOF
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
EOF
}

# extend the user model
_startapp_users() {
    cd ${PROJECT_NAME}
    # create users app
    /venv/bin/python manage.py startapp users
    # update settings.py
    sed -i '/\x27django.contrib.staticfiles\x27,/a \\x27users\x27,' ${PROJECT_NAME}/settings.py
    sed -i '/AUTH_PASSWORD_VALIDATORS = \[/i AUTH_USER_MODEL = \x27users.CustomUser\x27' ${PROJECT_NAME}/settings.py
    sed -i '/MEDIA_ROOT.*/a LOGIN_REDIRECT_URL = \x27home\x27\nLOGOUT_REDIRECT_URL = \x27home\x27' ${PROJECT_NAME}/settings.py
    # create users/models.py
    cat > users/models.py <<EOF
from django.contrib.auth.models import AbstractUser
from django.db import models

class CustomUser(AbstractUser):
    # First/last name is not a global-friendly pattern
    name = models.CharField(blank=True, max_length=255)

    def __str__(self):
        return self.email
EOF
    # create users/forms.py
    cat > users/forms.py <<EOF
from django import forms
from django.contrib.auth.forms import UserCreationForm, UserChangeForm
from .models import CustomUser

class CustomUserCreationForm(UserCreationForm):

    class Meta(UserCreationForm.Meta):
        model = CustomUser
        fields = ('username', 'email')

class CustomUserChangeForm(UserChangeForm):

    class Meta:
        model = CustomUser
        fields = UserChangeForm.Meta.fields
EOF
    # create users/admin.py
    cat > users/admin.py <<EOF
from django.contrib import admin
from django.contrib.auth import get_user_model
from django.contrib.auth.admin import UserAdmin

from .forms import CustomUserCreationForm, CustomUserChangeForm
from .models import CustomUser

class CustomUserAdmin(UserAdmin):
    add_form = CustomUserCreationForm
    form = CustomUserChangeForm
    model = CustomUser
    list_display = ['username', 'email', 'first_name', 'last_name', 'date_joined', 'last_login']

admin.site.register(CustomUser, CustomUserAdmin)
EOF
    # create users/templates directory
    mkdir -p users/templates/registration
    # create registration/login.html
    cat > users/templates/registration/login.html <<EOF
{% extends 'base.html' %}

{% block title %}Login{% endblock %}

{% block content %}
<h2>Login</h2>
<form method="post">
  {% csrf_token %}
  {{ form.as_p }}
  <button type="submit">Login</button>
</form>
{% endblock %}
EOF
    # create base.html
    cat > users/templates/base.html <<EOF
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>{% block title %}Django Start Project{% endblock %}</title>
</head>
<body>
  <main>
    {% block content %}
    {% endblock %}
  </main>
</body>
</html>
EOF
    # create home.html
    cat > users/templates/home.html <<EOF
{% extends 'base.html' %}

{% block title %}Home{% endblock %}

{% block content %}
{% if user.is_authenticated %}
  Hi {{ user.username }}!
  <p><a href="{% url 'logout' %}">logout</a></p>
{% else %}
  <p>You are not logged in</p>
  <a href="{% url 'login' %}">login</a> |
  <a href="{% url 'signup' %}">signup</a>
{% endif %}
{% endblock %}
EOF
    # create signup.html
    cat > users/templates/signup.html <<EOF
{% extends 'base.html' %}

{% block title %}Sign Up{% endblock %}

{% block content %}
  <h2>Sign up</h2>
  <form method="post">
    {% csrf_token %}
    {{ form.as_p }}
    <button type="submit">Sign up</button>
  </form>
{% endblock %}
EOF
    # create users/urls.py
    cat > users/urls.py <<EOF
from django.urls import path
from . import views

urlpatterns = [
    path('signup/', views.SignUp.as_view(), name='signup'),
]
EOF
    # create users/views.py
    cat > users/views.py <<EOF
from django.urls import reverse_lazy
from django.views import generic

from .forms import CustomUserCreationForm

class SignUp(generic.CreateView):
    form_class = CustomUserCreationForm
    success_url = reverse_lazy('login')
    template_name = 'signup.html'
EOF
    # update main urls.py
    sed -i '/from django.contrib import admin/,/\]/d' ${PROJECT_NAME}/urls.py
    cat >> ${PROJECT_NAME}/urls.py <<EOF
from django.contrib import admin
from django.urls import path, include
from django.views.generic.base import TemplateView

urlpatterns = [
    path('', TemplateView.as_view(template_name='home.html'), name='home'),
    path('admin/', admin.site.urls),
    path('users/', include('users.urls')),
    path('users/', include('django.contrib.auth.urls')),
]
EOF
    # generate migrations for users
    /venv/bin/python manage.py makemigrations users
}

### main ###
if [ ! -f /code/requirements.txt ]; then
    cp /requirements.txt /code/requirements.txt
    RM_REQTS_FILE=true
else
    RM_REQTS_FILE=false
fi

python -m venv /venv
source /venv/bin/activate
/venv/bin/pip install --upgrade pip
/venv/bin/pip install -r requirements.txt

/venv/bin/django-admin startproject $PROJECT_NAME
/venv/bin/pip freeze  > /code/$PROJECT_NAME/requirements.txt

_generate_env
source /code/$PROJECT_NAME/$PROJECT_NAME/.env

_update_settings_py
_generate_uwsgi_ini
_generate_run_uwsgi_sh
_generate_dockerfile
_generate_docker_entrypoint_sh
_generate_docker_compose_yml
_startapp_users
# add secrets file after all migrations have been run
_generate_secrets_py

# clean up 
if $RM_REQTS_FILE; then
    rm -f /code/requirements.txt
fi
rm -f /code/${PROJECT_NAME}/db.sqlite3

exit 0;