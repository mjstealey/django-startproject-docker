# Django startproject in Docker

### What is Django?

Django is a high-level Python Web framework that encourages rapid development and clean, pragmatic design. Built by experienced developers, it takes care of much of the hassle of Web development, so you can focus on writing your app without needing to reinvent the wheel. It’s free and open source.

### What this project does:

Generates the necessary files to start a new Django project using Docker based scripts with

- Python 3.6 based Docker definition ([python:3.6](https://hub.docker.com/_/python/))
- Virtual environment managed by virtualenv ([virtualenv tool](https://virtualenv.pypa.io/en/stable/))
- PostgreSQL database backend adapter ([psycopg2-binary](https://pypi.org/project/psycopg2-binary/))
- uWSGI based run scripts ([uWGSI](https://pypi.org/project/uWSGI/))
- python-dotenv app settings management ([python-dotenv](https://pypi.org/project/python-dotenv/))
- Optional Nginx web server (`--nginx` flag)
  - Implements uWSGI socket file
  - Provides an HTTP service configuration for use in Docker
  - Provides stub configuration for HTTPS / SSL use

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
  
  Usage: django-startproject-docker [-nh] [-o owner_uid] [-z owner_gid] [-u uwsgi_uid] [-g uwsgi_gid]
           -n|--nginx     = Include Nginx service definition files with build output
           -h|--help      = Help/Usage output
           -o|--owner-uid = Host UID to attribute output file ownership to (default=1000)
           -z|--owner-gid = Host GID to attribute output file ownership to (default=1000)
           -u|--uwsgi-uid = Host UID to run the uwsgi service as (default=0)
           -g|--uwsgi-gid = Host GID to run the uwsgi service as (default=0)
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
$ tree example
example                         # Project root
├── Dockerfile                  # Dockerfile definition for django container
├── apps                        # Django apps directory
├── docker-compose.yml          # Compose definition for running django app
├── docker-entrypoint.sh        # Entry point definition for django container
├── example                     # Primary project directory
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

6 directories, 21 files
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
  --owner-gid $(id -g) \
  --uwsgi-uid $(id -u) \
  --uwsgi-gid $(id -g)
```

The above generates output files as a new Django project named `example`.

```console
$ tree example
example                         # Project root
├── Dockerfile                  # Dockerfile definition for django container
├── apps                        # Django apps directory
├── docker-compose.yml          # Compose definition for running django app
├── docker-entrypoint.sh        # Entry point definition for django container
├── example                     # Primary project directory
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

7 directories, 24 files
```

File ownership should be that of the user that made the `docker run` call. Ownership of files is an explicit option as the files are created by a docker container, and would otherwise be owned by potentially a non-system user.

Additionally the `uwsgi` service will be spawned using the user's UID and GID values which can be observed in the `run_uwsgi.sh` script (these would otherwise default to the root user).

## Running your project

The generated output includes all of the necessary files to start running your Django project locally, or in Docker.

- **NOTE** - The default settings assume that a PostgreSQL database connection exists which is defined in the `docker-compose.yml` file. The user can change this by modifying the contents of `settings/config.py` to the database of their choosing.

## Run locally with Python 3

### Option 1: uWSGI runs the HTTP server 

**Database**

Start the pre-defined PostgreSQL database.

```
cd example/
docker-compose up -d database
```

Validate that the database container is running.

```console
$ docker-compose ps
  Name                Command              State           Ports
-------------------------------------------------------------------------
database   docker-entrypoint.sh postgres   Up      0.0.0.0:5432->5432/tcp
```

**Django server**

Run using virtualenv.

```
$ virtualenv -p $(which python3) venv
$ source venv/bin/activate
(venv)$ pip install --upgrade pip
(venv)$ pip install -r requirements.txt
(venv)$ ./run_uwsgi.sh
```

Validate that the Django is running site at [http://localhost:8000/](http://localhost:8000/)

![Django startproject init](https://user-images.githubusercontent.com/5332509/39456943-158aefc2-4cb8-11e8-9c46-b92660665209.png)

You will notice that a new directoriy has been created named `venv`. This directory contains the Python binary (allowing creation of environments with various Python versions) and can have its own independent set of installed Python packages in its site directories.

### Option 2: Nginx runs the HTTP server

**Database** and **Nginx**

Launch the `database` and `nginx` containers

```console
$ docker-compose up -d database nginx
Creating nginx    ... done
Creating database ... done
$ docker-compose ps
  Name                Command              State                      Ports
----------------------------------------------------------------------------------------------
database   docker-entrypoint.sh postgres   Up      0.0.0.0:5432->5432/tcp
nginx      nginx -g daemon off;            Up      0.0.0.0:8443->443/tcp, 0.0.0.0:8080->80/tcp
```

**Django server**

Run using virtualenv.

```
$ virtualenv -p $(which python3) venv
$ source venv/bin/activate
(venv)$ pip install --upgrade pip
(venv)$ pip install -r requirements.txt
(venv)$ ./run_uwsgi.sh
```

**NOTE**: Depending on your system you may observe the following warning

```console
!!! no internal routing support, rebuild with pcre support !!!
```

In this case Nginx might respond with **502 Bad Gateway** and have logs similar to:

```console
$ docker-compose logs nginx
Attaching to nginx
nginx       | 2018/05/29 20:34:19 [error] 7#7: *4 connect() to unix:///code/example.sock failed (111: Connection refused) while connecting to upstream, client: 172.19.0.1, server: 127.0.0.1:8080, request: "GET / HTTP/1.1", upstream: "uwsgi://unix:///code/example.sock:", host: "127.0.0.1:8080"
nginx       | 172.19.0.1 - - [29/May/2018:20:34:19 +0000] "GET / HTTP/1.1" 502 174 "-" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.13; rv:60.0) Gecko/20100101 Firefox/60.0" "-"
...
```

You'll either need to install the appropriate pcre packages and rebuild `uwsgi`, or run everything with docker.

## Run everything with docker

Local files are shared with the `django` Docker container (and optionally the `nginx` container) using a volume mount. Volume mounts are specified in the `docker-compose.yml` as follows

```yaml
volumes:
  - .:/code                 # Project root
  - ./static:/code/static   # Django static files
  - ./media:/code/media     # Django media files
```

Run using the generated `docker-compose.yml` file 

```
cd example/
docker-compose up -d
```

Check the status of the containers:

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

## Additional References

- Django docs: [https://docs.djangoproject.com/en/2.0/](https://docs.djangoproject.com/en/2.0/)
- Docker docs: [https://docs.docker.com](https://docs.docker.com)
- Docker Compose docs: [https://docs.docker.com/compose/](https://docs.docker.com/compose/)
- uWSGI options: [http://uwsgi-docs.readthedocs.io/en/latest/Options.html](http://uwsgi-docs.readthedocs.io/en/latest/Options.html)
- Nginx docs: [https://nginx.org/en/docs/](https://nginx.org/en/docs/)
