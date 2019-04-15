# Django startproject in Docker

The goal of this project is to make a ready to deploy Django installation in Docker as easy as possible. Deployment options include using uWSGI as the HTTP server (local development), using Nginx to run the HTTP server (http services for the web), or using Nginx to run the HTTP server with SSL support (https services for the web).

Defaults include:

- Custom User model defined from the start
- uWSGI based server (optionally use Nginx as the web server)
- PostgreSQL backend (using psycopg2-binary)
- Pytest integration (using pytest, pytest-cov, pytest-django)
- Python .ENV app settings management (using python-dotenv)
- Docker Compose based services

In addition to my own Docker based exploits, this work was inspired by:

- Caktus Group's blog: [Here's a Production-Ready Dockerfile for Your Python/Django App](https://www.caktusgroup.com/blog/2017/03/14/production-ready-dockerfile-your-python-django-app/)
- Will Vincent's blog: [Django Tips #6: Custom User Model](https://wsvincent.com/django-tips-custom-user-model/)

## Table of Contents

- [About](#about)
- [Setup and Requirements](#setup)
- [Deployment Options](#options)
  - [uWSGI runs the HTTP server (port 8000)](#develop)
  - [Nginx runs the HTTP server (port 8080)](#http)
  - [Nginx runs the HTTP server using SSL (port 8443)](#https)
- [Running the application](#run)
  - [Run everything in Docker](#docker)
  - [Run Django locally](#local)
- [References](#references) 

## <a name="about"></a>About

### What is Django?

Django is a high-level Python Web framework that encourages rapid development and clean, pragmatic design. Built by experienced developers, it takes care of much of the hassle of Web development, so you can focus on writing your app without needing to reinvent the wheel. It’s free and open source.

### What this project does:

Generates a ready to run [Django](https://www.djangoproject.com) project using Docker based scripts with

- Custom User model per [Django's recommendation](https://docs.djangoproject.com/en/2.2/topics/auth/customizing/#using-a-custom-user-model-when-starting-a-project)
- Python 3 based Docker definition ([python:3](https://hub.docker.com/_/python/) on Dockerhub)
- Virtual environment managed by virtualenv ([virtualenv tool](https://virtualenv.pypa.io/en/stable/))
- PostgreSQL database backend adapter ([psycopg2-binary](https://pypi.org/project/psycopg2-binary/))
- uWSGI based run scripts ([uWGSI](https://pypi.org/project/uWSGI/))
- python-dotenv app settings management ([python-dotenv](https://pypi.org/project/python-dotenv/))
- pytest [Python testing tool](https://docs.pytest.org/en/latest/)
  - pytest-django [plugin](https://pytest-django.readthedocs.io/en/latest/index.html)
  - pytest-cov [plugin](https://pytest-cov.readthedocs.io/en/latest/)
- Docker Compose definition and environment files
- Nginx web server (`--nginx` flag) ([nginx](https://docs.docker.com/samples/library/nginx/) on Dockerhub)
  - Implements uWSGI socket file
  - Provides an HTTP service configuration for use in Docker
  - Provides stub configuration for HTTPS / SSL using self generated certificates
  - Unix socket protocol for Django services
  - Host ports mapped as `8080:80` and `8443:443` by default


Project files are designed to be run either locally using virtualenv, or in Docker using the generated `docker-compose.yml` file. Virtualenv is used within Docker for improved environment isolation.

### What this project doesn't do:

This project does not generate trusted HTTPS / SSL certificates.

- These are stubbed as self-signed certificates and left to the user to implement using the methods that best fit their scenario.

## <a name="setup"></a>Setup and Requirements

Setup is simple, and you don't even need to clone this repository as everything you need is already included in the **django-startproject-docker** image on Docker Hub.

### Pull image from [dockerhub](https://hub.docker.com/r/mjstealey/django-startproject-docker/)

```
docker pull mjstealey/django-startproject-docker:latest
```

### Build locally

Optionally you can clone the repository and build the `mjstealey/django-startproject-docker` image yourself. This allows you the opportunity to modify the build to your specific requirements if needed.

```
docker build -t mjstealey/django-startproject-docker .
```

### System Requirements

There are a small set of system requirements in order to run the output of this code. If you're planning on doing additional development, which is most likely the case, then additional requirements may be applicable.

To Run

- Docker
- Docker Compose

To Develop

- Docker
- Docker Compose
- Python 3 / Pip 3
- Virtualenv


## <a name="options"></a>Deployment Options

Depending on your goal, there are three deployment scenarios to consider.

1. [uWSGI runs the HTTP server](#develop) - suitable for local development and testing, but not necessarily for web deployment
2. [Nginx runs the HTTP server](#http) - suitable for web deployment but does not make use of SSL encryption (non-production)
3. [Nginx runs the HTTP server using SSL](#https) - suitable for web deployment and makes use of SSL encryption (production)

When the **django-startproject-docker** container is run it will generate your Django project files using the configuration options you provide.

- `-e PROJECT_NAME=example_project` - name given to the Django project
- `-v LOCAL_VOL:/code` - project files are generated within the container's `/code` direcotry. Share a volume from the host to persist these files locally.

Additional usage options can be discovered by using the `-h|--help` flag:

```console
$ docker run --rm mjstealey/django-startproject-docker --help
### Help ###

Usage: django-startproject-docker [-nsh] [-o owner_uid] [-z owner_gid] [-u uwsgi_uid] [-g uwsgi_gid]
         -n|--nginx          = Include Nginx service definition files with build output
         -s|--ssl-certs      = Generate self-signed SSL certificates and configure Nginx to use https
         -h|--help           = Help/Usage output
         -o|--owner-uid      = UID to attribute output file ownership to (default=1000)
         -z|--owner-gid      = GID to attribute output file ownership to (default=1000)
         -u|--uwsgi-uid      = UID to run the uwsgi service as (default=1000)
         -g|--uwsgi-gid      = GID to run the uwsgi service as (default=1000)
```

**NOTE**: It is generally a good idea to set the `-o|--owner-uid` and `-z|--owner-gid` flags to be that of the user that will be running the application. So, if the current user were to be the same as the one running the application, these flags would take the form of `--owner-uid $(id -u)` and `--owner-gid $(id -g)`.

## <a name="develop"></a>uWSGI runs the HTTP server (port 8000)

This configuration is suitable for local development and testing, but not necessarily for web deployment. The default configuration will run at [http://localhost:8000/]().

Let's create a new project named **example_project** in the present working directory with files owned by the current user.

```
docker run --rm \
  -e PROJECT_NAME=example_project \
  -v $(pwd):/code \
  mjstealey/django-startproject-docker \
  --owner-uid $(id -u) \
  --owner-gid $(id -g)
```

Let's look at the generated files.

```console
$ tree -a example_project
example_project                # Project root
├── .env                       # Compose .env file (ignored by git)
├── .gitignore                 # Git .gitignore file
├── Dockerfile                 # Dockerfile definition for django constainer
├── conftest.py                # Pytest configuration file
├── docker-compose.yml         # Compose definition for running the Django application stack
├── docker-entrypoint.sh       # Entry point definition for django container
├── env.template               # Compose .env template file
├── example_project            # Primary project directory
│   ├── .env                   # Python .env file (ignored by git)
│   ├── __init__.py            # Python init
│   ├── env.template           # Python .env template file
│   ├── runner.py              # Pytest test runner for Django
│   ├── secrets.py             # Django secrets file (ignored by git)
│   ├── secrets.py.template    # Django secrets template file
│   ├── settings.py            # Main Django settings file
│   ├── urls.py                # Main Django urls file
│   └── wsgi.py                # Django WSGI file
├── example_project_uwsgi.ini  # uWSGI configuration file
├── manage.py                  # Django manage.py file
├── media                      # Django media files directory (ignored by git)
├── pg_data                    # PostgreSQL host volume (ignored by git)
│   ├── data                   # PostgreSQL data
│   └── logs                   # PostgreSQL logs
├── pytest.ini                 # Pytest configuration file
├── requirements.txt           # Pip install requirements file
├── run_uwsgi.sh               # uWSGI run script
├── static                     # Django static files directory (ignored by git)
└── users                      # Django users app for CustomUser 
    ├── __init__.py            # Python init
    ├── admin.py               # CustomUser admin 
    ├── apps.py                # CustomUser apps
    ├── forms.py               # CustomUser forms
    ├── migrations             # CustomUser migrations directory
    │   └── __init__.py        # Python init
    ├── models.py              # CustomUser model definition
    ├── tests.py               # CustomUser tests 
    └── views.py               # CustomUser views

8 directories, 29 files 
```

Now lets [run it](#run)!

## <a name="http"></a>Nginx runs the HTTP server (port 8080)

This configuration is suitable for web deployment but does not make use of SSL encryption (non-production). The default configuration will run at [http://localhost:8080/]().

Let's create a new project named **example_project** in the present working directory with files owned by the current user using Nginx as the web server.

```
docker run --rm \
  -e PROJECT_NAME=example_project \
  -v $(pwd):/code \
  mjstealey/django-startproject-docker \
  --nginx \
  --owner-uid $(id -u) \
  --owner-gid $(id -g)
```

Let's look at the generated files.

```console
$ tree -a example_project
example_project
├── .env
├── .gitignore
├── Dockerfile
├── conftest.py
├── docker-compose.yml
├── docker-entrypoint.sh
├── env.template
├── example_project
│   ├── .env
│   ├── __init__.py
│   ├── env.template
│   ├── runner.py
│   ├── secrets.py
│   ├── secrets.py.template
│   ├── settings.py
│   ├── urls.py
│   └── wsgi.py
├── example_project_uwsgi.ini
├── manage.py
├── media
├── nginx                          # Nginx directory
│   ├── default.conf               # Nginx default http configuration (ignored by git)
│   ├── default.conf.template      # Nginx default http configuration template
│   └── default_ssl.conf.template  # Nginx default https configuration template
├── pg_data
│   ├── data
│   └── logs
├── pytest.ini
├── requirements.txt
├── run_uwsgi.sh
├── static
├── users
│   ├── __init__.py
│   ├── admin.py
│   ├── apps.py
│   ├── forms.py
│   ├── migrations
│   │   └── __init__.py
│   ├── models.py
│   ├── tests.py
│   └── views.py
└── uwsgi_params

9 directories, 33 files
```

Now lets [run it](#run)!

## <a name="https"></a>Nginx runs the HTTP server using SSL (port 8443)

This configuration is suitable for web deployment and makes use of SSL encryption (production), and is preferred.The default configuration will run at [https://localhost:8443/]().

Let's create a new project named **example_project** in the present working directory with files owned by the current user using Nginx as the web server with SSL support.

```
docker run --rm \
  -e PROJECT_NAME=example_project \
  -v $(pwd):/code \
  mjstealey/django-startproject-docker \
  --nginx \
  --ssl-certs \
  --owner-uid $(id -u) \
  --owner-gid $(id -g)
```

Let's look at the generated files.

```console
$ tree -a example_project
example_project
├── .env
├── .gitignore
├── Dockerfile
├── conftest.py
├── docker-compose.yml
├── docker-entrypoint.sh
├── env.template
├── example_project
│   ├── .env
│   ├── __init__.py
│   ├── env.template
│   ├── runner.py
│   ├── secrets.py
│   ├── secrets.py.template
│   ├── settings.py
│   ├── urls.py
│   └── wsgi.py
├── example_project_uwsgi.ini
├── manage.py
├── media
├── nginx                          # Nginx directory
│   ├── default.conf               # Nginx default http configuration (ignored by git)
│   ├── default.conf.template      # Nginx default http configuration template
│   └── default_ssl.conf.template  # Nginx default https configuration template
├── pg_data
│   ├── data
│   └── logs
├── pytest.ini
├── requirements.txt
├── run_uwsgi.sh
├── ssl                             # SSL directory
│   ├── ssl_dev.crt                 # Self signed SSL certificate file
│   └── ssl_dev.key                 # Self signed SSL key file
├── static
├── users
│   ├── __init__.py
│   ├── admin.py
│   ├── apps.py
│   ├── forms.py
│   ├── migrations
│   │   └── __init__.py
│   ├── models.py
│   ├── tests.py
│   └── views.py
└── uwsgi_params

10 directories, 35 files
```

Now lets [run it](#run)!

## <a name="run"></a>Running the application

Running the application is the same regardless of the configuration you used to generate the files. 

- Running everything in Docker should yield the Django welcome page once the containers finish their setup scripts.
- Running Django locally will take a little more configuration and is somewhat dependent on your local system (macOS, Linux or Windows)

## <a name="docker"></a>Run everything in Docker

To run everything in Docker, simply change into the project's root directory and bring the containers up.

```
cd example_project
docker-compose up -d
```

Files from your host will be shared with the running Docker containers using volume mounts.

The `django` container

```docker
volumes:
  - .:/code
  - ./static:/code/static
  - ./media:/code/media
```

The `nginx` container

```docker
volumes:
  - .:/code
  - ./static:/code/static
  - ./media:/code/media
  - ${NGINX_DEFAULT_CONF:-./nginx/default.conf}:/etc/nginx/conf.d/default.conf
  - ${NGINX_SSL_CERT:-./ssl/ssl_dev.crt}:/etc/ssl/SSL.crt  # SSL certificate
  - ${NGINX_SSL_KEY:-./ssl/ssl_dev.key}:/etc/ssl/SSL.key   # SSL key
```

### uWSGI runs the HTTP server

Two docker containers should be observed running

```console
$ docker-compose ps
  Name                Command              State           Ports
-------------------------------------------------------------------------
database   docker-entrypoint.sh postgres   Up      0.0.0.0:5432->5432/tcp
django     /code/docker-entrypoint.sh      Up      0.0.0.0:8000->8000/tcp
```

You Django project should now be running at: [http://localhost:8000/]()

<img width="80%" alt="uWSGI on port 8000" src="https://user-images.githubusercontent.com/5332509/56152462-b692ba80-5f81-11e9-8732-834cb9736857.png">

### Nginx runs the HTTP server

Three docker containers should be observed running

```console
$ docker-compose ps
  Name                Command              State                      Ports
----------------------------------------------------------------------------------------------
database   docker-entrypoint.sh postgres   Up      0.0.0.0:5432->5432/tcp
django     /code/docker-entrypoint.sh      Up      0.0.0.0:8000->8000/tcp
nginx      nginx -g daemon off;            Up      0.0.0.0:8443->443/tcp, 0.0.0.0:8080->80/tcp
```

You Django project should now be running at: [http://localhost:8080/]()

<img width="80%" alt="Nginx on port 8080" src="https://user-images.githubusercontent.com/5332509/56153471-3b7ed380-5f84-11e9-966a-493c16a88a8f.png">

### Nginx runs the HTTP server using SSL

Three docker containers should be observed running

```console
$ docker-compose ps
  Name                Command              State                      Ports
----------------------------------------------------------------------------------------------
database   docker-entrypoint.sh postgres   Up      0.0.0.0:5432->5432/tcp
django     /code/docker-entrypoint.sh      Up      0.0.0.0:8000->8000/tcp
nginx      nginx -g daemon off;            Up      0.0.0.0:8443->443/tcp, 0.0.0.0:8080->80/tcp
```

You Django project should now be running at: [https://localhost:8443/](). Accept the dialogue regarding a non-trusted CA as the SSL certificates are self generated.

<img width="80%" alt="Nginx with SSL on port 8443" src="https://user-images.githubusercontent.com/5332509/56153950-53a32280-5f85-11e9-9296-950d7ec6d2b4.png">

<img width="80%" alt="Nginx with SSL on port 8443" src="https://user-images.githubusercontent.com/5332509/56153952-53a32280-5f85-11e9-9116-686207d102e4.png">

## <a name="local"></a>Run Django locally

By default this project is configured to run everything in Docker which may be non-optimal for development. In order to enable local development using Python 3 the user must make a few small changes prior to running the code.

### virtualenv and database

Create the virtual environment and install packages from the Django root directory

```
virtualenv -p $(which python3) venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

Start the pre-defined PostgreSQL database in Docker

Update `POSTGRES_HOST` in the Django .env file to reflect the IP of your local machine (For example, from `export POSTGRES_HOST=database` to `export POSTGRES_HOST=127.0.0.1`)

```
docker-compose up -d database
```

Validate that the database container is running.

```console
$ docker-compose ps
  Name                Command              State           Ports
-------------------------------------------------------------------------
database   docker-entrypoint.sh postgres   Up      0.0.0.0:5432->5432/tcp
```
### Option 1. uWSGI runs the HTTP server 

Update the uWSGI ini file

```ini
...
; use protocol uwsgi over TCP socket (use if UNIX file socket is not an option)
;socket              = :8000
; add an http router/server on the specified address **port**
http                = :8000
; map mountpoint to static directory (or file) **port**
static-map          = /static/=static/
static-map          = /media/=media/
; bind to the specified UNIX/TCP socket using uwsgi protocol (full path) **socket**
;uwsgi-socket        = ./django.sock
; ... with appropriate permissions - may be needed **socket**
;chmod-socket        = 666
...
```

Execute the `run_uwsgi.sh` script

```
UWSGI_UID=$(id -u) UWSGI_GID=$(id -g) ./run_uwsgi.sh
```

- **NOTE**: the `uwsgi` service will be spawned using the user's **UID** and **GID** values. These would otherwise default to `UID=1000` and `GID=1000` as denoted in the `run_uwsgi.sh` script.

Validate that the Django is running site at [http://localhost:8000/]()

<img width="80%" alt="uWSGI on port 8000" src="https://user-images.githubusercontent.com/5332509/56152462-b692ba80-5f81-11e9-8732-834cb9736857.png">

### Option 2. Nginx runs the HTTP server (with or without SSL)

**NOTE**: Depending on your system (macOS) you may not be able to run the Nginx server using file sockets mounted from the host. For more information refer to this Github issue: [Support for sharing unix sockets](https://github.com/docker/for-mac/issues/483). If this is the case, you'll either need to run your Nginx server over ports, or run everything in Docker. The following will describe how to run the Nginx server using TCP ports.

Update the uWSGI ini file

```ini
...
; use protocol uwsgi over TCP socket (use if UNIX file socket is not an option)
socket              = :8000
; add an http router/server on the specified address **port**
;http                = :8000
; map mountpoint to static directory (or file) **port**
;static-map          = /static/=static/
;static-map          = /media/=media/
; bind to the specified UNIX/TCP socket using uwsgi protocol (full path) **socket**
;uwsgi-socket        = ./django.sock
; ... with appropriate permissions - may be needed **socket**
;chmod-socket        = 666
...
```

Update the Nginx configuration file to use the TCP socket (http or https)

```conf
# the upstream component nginx needs to connect to
upstream django {
    #server unix:///code/django.sock; # UNIX file socket
    # Defaulting to macOS equivalent of docker0 network for TCP socket
    server host.docker.internal:8000; # TCP socket
}
```

- **NOTE**: `host.docker.internal` is macOS specific, substitute as required by your operating system

Launch the `nginx` container

```
docker-compose up -d nginx
```

Validate that both the database and nginx containers are running.

```console
 docker-compose ps
  Name                Command              State                      Ports
----------------------------------------------------------------------------------------------
database   docker-entrypoint.sh postgres   Up      0.0.0.0:5432->5432/tcp
nginx      nginx -g daemon off;            Up      0.0.0.0:8443->443/tcp, 0.0.0.0:8080->80/tcp
```

Execute the `run_uwsgi.sh` script

```
UWSGI_UID=$(id -u) UWSGI_GID=$(id -g) ./run_uwsgi.sh
```

- **NOTE**: the `uwsgi` service will be spawned using the user's **UID** and **GID** values. These would otherwise default to `UID=1000` and `GID=1000` as denoted in the `run_uwsgi.sh` script.

Validate that the Django is running site at [http://localhost:8080/]()

<img width="80%" alt="Nginx with SSL on port 8443" src="https://user-images.githubusercontent.com/5332509/56153952-53a32280-5f85-11e9-9116-686207d102e4.png">

- **NOTE**: you should be automatically redirected to port `8443` if using Nginx with SSL certificates.

## <a name="references"></a>References

- Django docs: [https://docs.djangoproject.com/en/2.2/](https://docs.djangoproject.com/en/2.2/)
- Docker docs: [https://docs.docker.com](https://docs.docker.com)
- Docker Compose docs: [https://docs.docker.com/compose/](https://docs.docker.com/compose/)
- uWSGI options: [http://uwsgi-docs.readthedocs.io/en/latest/Options.html](http://uwsgi-docs.readthedocs.io/en/latest/Options.html)
- Nginx docs: [https://nginx.org/en/docs/](https://nginx.org/en/docs/)
