# Django startproject in Docker

### What is Django?

Django is a high-level Python Web framework that encourages rapid development and clean, pragmatic design. Built by experienced developers, it takes care of much of the hassle of Web development, so you can focus on writing your app without needing to reinvent the wheel. It’s free and open source.

### What this project does:

Generates the necessary files to start a new [Django 2.1](https://www.djangoproject.com) project using Docker based scripts with

- Python 3.7 based Docker definition ([python:3.7](https://hub.docker.com/_/python/))
- Virtual environment managed by virtualenv ([virtualenv tool](https://virtualenv.pypa.io/en/stable/))
- PostgreSQL database backend adapter ([psycopg2-binary](https://pypi.org/project/psycopg2-binary/))
- uWSGI based run scripts ([uWGSI](https://pypi.org/project/uWSGI/))
- python-dotenv app settings management ([python-dotenv](https://pypi.org/project/python-dotenv/))
- Optional Nginx web server (`--nginx` flag)
  - Implements uWSGI socket file
  - Provides an HTTP service configuration for use in Docker
  - Provides stub configuration for HTTPS / SSL use
  - Unix socket protocol for Django services
  - Host ports mapped as `8080:80` and `8443:443` by default
- Optional split settings files (`--split-settings` flag)
    - Creates a `settings/` directory with proper reference updates
    - Splits the `settings.py` file into separate files based on their purpose (api, applications, auth, config, logging, main, secrets and tasks)

Project files are designed to be run either locally using virtualenv, or in Docker using the generated `docker-compose.yml` file. Virtualenv is also used within Docker for improved environment isolation.

### What this project doesn't do:

This project does not define the following:

- Implement HTTPS / SSL certificate handling

These are stubbed and left to the user to implement using the methods that best fit their scenario.

## Starting a new project

### Pull image from [dockerhub](https://hub.docker.com/r/mjstealey/django-startproject-docker/)

```
docker pull mjstealey/django-startproject-docker
```

- Optionally the user can build the `mjstealey/django-startproject-docker` image locally from the included Dockerfile

    ```
    docker build -t mjstealey/django-startproject-docker .
    ```

### Run `mjstealey/django-startproject-docker`

Configure the docker run call to specify your project's settings

- Django project name set using the `PROJECT_NAME` variable (default `PROJECT_NAME=example`)
- Volume mount a local directory to `:/code` to save the Django project files to
- Additional options can be found using `-h|--help`

```console
$ docker run --rm mjstealey/django-startproject-docker --help
### Help ###

Usage: django-startproject-docker [-nsh] [-o owner_uid] [-z owner_gid] [-u uwsgi_uid] [-g uwsgi_gid]
         -n|--nginx          = Include Nginx service definition files with build output
         -s|--split-settings = Split settings files into their own directory structure
         -h|--help           = Help/Usage output
         -o|--owner-uid      = Host UID to attribute output file ownership to (default=1000)
         -z|--owner-gid      = Host GID to attribute output file ownership to (default=1000)
         -u|--uwsgi-uid      = Host UID to run the uwsgi service as (default=0)
         -g|--uwsgi-gid      = Host GID to run the uwsgi service as (default=0)
```

### Option 1: uWSGI runs the HTTP server

Default configuration runs on port `8000`

```
docker run --rm \
  -e PROJECT_NAME=example \
  -v $(pwd):/code \
  mjstealey/django-startproject-docker \
  --owner-uid $(id -u) \
  --owner-gid $(id -g)
```

The above generates output files as a new Django project named `example`.

```console
$ tree -a example
example                         # Project root
├── .gitignore                  # Git .gitignore file
├── Dockerfile                  # Dockerfile definition for django constainer
├── apps                        # Django apps directory
├── docker-compose.yml          # Compose definition for running django app
├── docker-entrypoint.sh        # Entry point definition for django container
├── example                     # Primary project directory
│   ├── .env                    # Python .env file
│   ├── __init__.py             # Python init
│   ├── dummy_secrets.py        # Django secrets file (example file)
│   ├── secrets.py              # Django secrets file (with key)
│   ├── settings.py             # Main Django settings file
│   ├── urls.py                 # Django urls file
│   └── wsgi.py                 # Django WSGI file
├── example_uwsgi.ini           # uWSGI configuration file
├── manage.py                   # Django manage.py file
├── media                       # Django media files directory
├── plugins                     # Django plugins directory
│   └── __init__.py             # Python init
├── requirements.txt            # Pip install requirements file
├── run_uwsgi.sh                # uWSGI run script
└── static                      # Django static files directory

5 directories, 16 files
```

File ownership should be that of the user that made the `docker run` call. Ownership of files is an explicit option as the files are created by a docker container, and would otherwise be owned by potentially a non-system user.

### Option 2: Nginx runs the HTTP server

Default configuration runs on port `8080`

```
docker run --rm \
  -e PROJECT_NAME=example \
  -v $(pwd):/code \
  mjstealey/django-startproject-docker \
  --nginx \
  --owner-uid $(id -u) \
  --owner-gid $(id -g)
```

The above generates output files as a new Django project named `example`.

```console
$ tree -a example
example                         # Project root
├── .gitignore                  # Git .gitignore file
├── Dockerfile                  # Dockerfile definition for django constainer
├── apps                        # Django apps directory
├── docker-compose.yml          # Compose definition for running django app
├── docker-entrypoint.sh        # Entry point definition for django container
├── example                     # Primary project directory
│   ├── .env                    # Python .env file
│   ├── __init__.py             # Python init
│   ├── dummy_secrets.py        # Django secrets file (example file)
│   ├── secrets.py              # Django secrets file (with key)
│   ├── settings.py             # Main Django settings file
│   ├── urls.py                 # Django urls file
│   └── wsgi.py                 # Django WSGI file
├── example_uwsgi.ini           # uWSGI configuration file
├── manage.py                   # Django manage.py file
├── media                       # Django media files directory
├── nginx                       # Nginx configuration directory
│   ├── example_nginx.conf      # HTTP example Nginx conf
│   └── example_nginx_ssl.conf  # HTTPS example Nginx conf
├── plugins                     # Django plugins directory
│   └── __init__.py             # Python init
├── requirements.txt            # Pip install requirements file
├── run_uwsgi.sh                # uWSGI run script
└── static                      # Django static files directory

6 directories, 19 files
```

File ownership should be that of the user that made the `docker run` call. Ownership of files is an explicit option as the files are created by a docker container, and would otherwise be owned by potentially a non-system user.

## Running your project

The generated output files include everything necessary to start running your Django project in Docker. You can also run the `django` component from your local machine with `virtualenv` and some simple configuration changes.

![Django startproject init](https://user-images.githubusercontent.com/5332509/39456943-158aefc2-4cb8-11e8-9c46-b92660665209.png)

The default settings assume that a PostgreSQL database connection exists as defined in the `docker-compose.yml` file. The user can change this by modifying the contents of the `settings.py` and `.env` files to the database of their choosing.

## Run in Docker

Local files are shared with the `django` Docker container (and `nginx` container) using a volume mount. Volume mounts are specified in the `docker-compose.yml` as follows

```yaml
...
volumes:
  - .:/code                 # Project root
  - ./static:/code/static   # Django static files
  - ./media:/code/media     # Django media files
...
```

Launch the compose stack using the generated `docker-compose.yml` file 

```
cd example/
docker-compose up -d
```

Check the status of the containers and validate the running site:

- uWSGI option

    ```console
    $ docker-compose ps
      Name                Command              State                                  Ports
    ----------------------------------------------------------------------------------------------------------------------
    database   docker-entrypoint.sh postgres   Up      0.0.0.0:5432->5432/tcp
    django     /code/docker-entrypoint.sh      Up      0.0.0.0:8443->443/tcp, 0.0.0.0:8080->80/tcp, 0.0.0.0:8000->8000/tcp
    ```
    After a few moments validate that your Django server is running at [http://localhost:8000/](http://localhost:8000/)

- Nginx option

    ```console
    $ docker-compose ps
      Name                Command              State                      Ports
    ----------------------------------------------------------------------------------------------
    database   docker-entrypoint.sh postgres   Up      0.0.0.0:5432->5432/tcp
    django     /code/docker-entrypoint.sh      Up      0.0.0.0:8000->8000/tcp
    nginx      nginx -g daemon off;            Up      0.0.0.0:8443->443/tcp, 0.0.0.0:8080->80/tcp
    ```

    After a few moments validate that your Django server is running at [http://localhost:8080/](http://localhost:8080/)
    
## Run with virtualenv (Python 3)

### virtualenv and database

Create the virtual environment and install packages

```
$ virtualenv -p $(which python3) venv
$ source venv/bin/activate
(venv)$ pip install --upgrade pip
(venv)$ pip install -r requirements.txt
```

Start the pre-defined PostgreSQL database in Docker

- Update `POSTGRES_HOST` in `.env` to reflect the IP of your local machine (For example, from `export POSTGRES_HOST=database` to  `export POSTGRES_HOST=127.0.0.1`)
- Ensure the `POSTGRES_PORT=5432` is properly mapped to the host in the `docker-compose.yml` file

```
$ docker-compose up -d database
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
;uwsgi-socket        = ./example.sock
; ... with appropriate permissions - may be needed **socket**
;chmod-socket        = 666
...
```

Execute the `run_uwsgi.sh` script

```
(venv)$ UWSGI_UID=$(id -u) UWSGI_GID=$(id -g) ./run_uwsgi.sh
```

- **NOTE**: the `uwsgi` service will be spawned using the user's **UID** and **GID** values. These would otherwise default to `UID=1000` and `GID=1000` as denoted in the `run_uwsgi.sh` script.

Validate that the Django is running site at [http://localhost:8000/](http://localhost:8000/)

![Django startproject init](https://user-images.githubusercontent.com/5332509/39456943-158aefc2-4cb8-11e8-9c46-b92660665209.png)

### Option 2. Nginx runs the HTTP(s) server

**NOTE**: Depending on your system (macOS) you may not be able to run the Nginx server using sockets mounted from the host. For more information refer to this Github issue: [Support for sharing unix sockets](https://github.com/docker/for-mac/issues/483). If this is the case, you'll either need to run your Nginx server over ports, or run everything in Docker. The following will describe how to run the Nginx server using TCP ports.

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
;uwsgi-socket        = ./example.sock
; ... with appropriate permissions - may be needed **socket**
;chmod-socket        = 666
...
```

Update the nginx configuration file (http or https)

```conf
upstream django {
    #server unix:///code/${PROJECT_NAME}.sock; # UNIX file socket
    # Defaulting to macOS equivalent of docker0 network for TCP socket
    server docker.for.mac.localhost:8000; # TCP socket
}
```

- **NOTE**: `docker.for.mac.localhost` is macOS specific, substitute as required by your operating system

Update the docker-compose file (https only)

```yaml
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
      - ./nginx/example_nginx_ssl.conf:/etc/nginx/conf.d/default.conf  # SSL configuration file
      - PATH_TO/SSL.crt:/etc/ssl/SSL.crt                               # SSL cert file on host
      - PATH_TO/SSL.key:/etc/ssl/SSL.key                               # SSL key file on host
```

Launch the `nginx` container

```
$ docker-compose up -d nginx
```

Execute the `run_uwsgi.sh` script

```
(venv)$ UWSGI_UID=$(id -u) UWSGI_GID=$(id -g) ./run_uwsgi.sh
```

- **NOTE**: the `uwsgi` service will be spawned using the user's **UID** and **GID** values. These would otherwise default to `UID=1000` and `GID=1000` as denoted in the `run_uwsgi.sh` script.

Validate that the Django is running site at [http://localhost:8080/](http://localhost:8080/)

- **NOTE**: you should be automatically redirected to port `8443` if using https with SSL certificates.

## Split settings files

The `settings.py` file is removed and replaced by a `settings/` directory with separate files based on their purpose.

### uWSGI runs the HTTP server

Default configuration runs on port `8000`

```
docker run --rm \
  -e PROJECT_NAME=example \
  -v $(pwd):/code \
  mjstealey/django-startproject-docker \
  --split-settings \
  --owner-uid $(id -u) \
  --owner-gid $(id -g)
```

The above generates output files as a new Django project named `example`.

```console
$ tree -a example
example                         # Project root
├── .gitignore                  # Git .gitignore file
├── Dockerfile                  # Dockerfile definition for django container
├── apps                        # Django apps directory
├── docker-compose.yml          # Compose definition for running django app
├── docker-entrypoint.sh        # Entry point definition for django container
├── example                     # Primary project directory
│   ├── .env                    # Python .env file
│   ├── __init__.py             # Python init
│   ├── settings                # Django settings directory
│   │   ├── __init__.py         # Python init
│   │   ├── api.py              # API Django settings file (initially blank)
│   │   ├── applications.py     # Installed apps Django settings file
│   │   ├── auth.py             # Authentication Django settings file (initially blank)
│   │   ├── config.py           # Configuration Django settings file
│   │   ├── dummy_secrets.py    # Django secrets file (example file)
│   │   ├── logging.py          # Logging Django settings file
│   │   ├── main.py             # Main Django settings file
│   │   ├── secrets.py          # Django secrets file (with key)
│   │   └── tasks.py            # Tasks Django settings file (initially blank)
│   ├── urls.py                 # Django urls file
│   └── wsgi.py                 # Django WSGI file
├── example_uwsgi.ini           # uWSGI configuration file
├── manage.py                   # Django manage.py file
├── media                       # Django media files directory
├── plugins                     # Django plugins directory
│   └── __init__.py             # Python init
├── requirements.txt            # Pip install requirements file
├── run_uwsgi.sh                # uWSGI run script
└── static                      # Django static files directory

6 directories, 23 files
```

### Nginx runs the HTTP server

Default configuration runs on port `8080`

```
docker run --rm \
  -e PROJECT_NAME=example \
  -v $(pwd):/code \
  mjstealey/django-startproject-docker \
  --nginx \
  --split-settings \
  --owner-uid $(id -u) \
  --owner-gid $(id -g) \
  --uwsgi-uid $(id -u) \
  --uwsgi-gid $(id -g)
```

The above generates output files as a new Django project named `example`.

```console
$ tree -a example
example                         # Project root
├── .gitignore                  # Git .gitignore file
├── Dockerfile                  # Dockerfile definition for django container
├── apps                        # Django apps directory
├── docker-compose.yml          # Compose definition for running django app
├── docker-entrypoint.sh        # Entry point definition for django container
├── example                     # Primary project directory
│   ├── .env                    # Python .env file
│   ├── __init__.py             # Python init
│   ├── settings                # Django settings directory
│   │   ├── __init__.py         # Python init
│   │   ├── api.py              # API Django settings file (initially blank)
│   │   ├── applications.py     # Installed apps Django settings file
│   │   ├── auth.py             # Authentication Django settings file (initially blank)
│   │   ├── config.py           # Configuration Django settings file
│   │   ├── dummy_secrets.py    # Django secrets file (example file)
│   │   ├── logging.py          # Logging Django settings file
│   │   ├── main.py             # Main Django settings file
│   │   ├── secrets.py          # Django secrets file (with key)
│   │   └── tasks.py            # Tasks Django settings file (initially blank)
│   ├── urls.py                 # Django urls file
│   └── wsgi.py                 # Django WSGI file
├── example_uwsgi.ini           # uWSGI configuration file
├── manage.py                   # Django manage.py file
├── media                       # Django media files directory
├── nginx                       # Nginx configuration directory
│   ├── example_nginx.conf      # HTTP example Nginx conf
│   └── example_nginx_ssl.conf  # HTTPS example Nginx conf
├── plugins                     # Django plugins directory
│   └── __init__.py             # Python init
├── requirements.txt            # Pip install requirements file
├── run_uwsgi.sh                # uWSGI run script
├── static                      # Django static files directory
└── uwsgi_params                # Nginx uwsgi_params file

7 directories, 26 files
```


## Additional References

- Django docs: [https://docs.djangoproject.com/en/2.0/](https://docs.djangoproject.com/en/2.0/)
- Docker docs: [https://docs.docker.com](https://docs.docker.com)
- Docker Compose docs: [https://docs.docker.com/compose/](https://docs.docker.com/compose/)
- uWSGI options: [http://uwsgi-docs.readthedocs.io/en/latest/Options.html](http://uwsgi-docs.readthedocs.io/en/latest/Options.html)
- Nginx docs: [https://nginx.org/en/docs/](https://nginx.org/en/docs/)
