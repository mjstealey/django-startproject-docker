# Django startproject in Docker

### What is Django?

Django is a high-level Python Web framework that encourages rapid development and clean, pragmatic design. Built by experienced developers, it takes care of much of the hassle of Web development, so you can focus on writing your app without needing to reinvent the wheel. It’s free and open source.

### What this project does:

Generates the necessary files to start a new Django project using Docker based scripts with

- Python 3.6 base Docker definition ([python:3.6](https://hub.docker.com/_/python/))
- Virtual environment managed by virtualenv ([virtualenv tool](https://virtualenv.pypa.io/en/stable/))
- PostgreSQL database backend adapter ([psycopg2-binary](https://pypi.org/project/psycopg2-binary/))
- uWSGI based run scripts ([uWGSI](https://pypi.org/project/uWSGI/))
- python-dotenv app settings management ([python-dotenv](https://pypi.org/project/python-dotenv/))

Project files are designed to be run either locally using virtualenv, or in Docker using the generated `docker-compose.yml` file.

### What this project doesn't do:

This project does not define the following:

- Implement uWSGI socket files
- Generate web server definitions (ie: Nginx or Apache)
- Implement HTTPS / SSL certificate handling

These are left to the user to implement using the methods that best fit their scenario.

## Starting a new project

Pull image from [dockerhub](https://hub.docker.com/r/mjstealey/django-startproject-docker/)

```
docker pull mjstealey/django-startproject-docker
```

Or build the `mjstealey/django-startproject-docker` image from the included Dockerfile

```
docker build -t mjstealey/django-startproject-docker .
```

Run the `mjstealey/django-startproject-docker` image:

- Set your Django project name using the `PROJECT_NAME` variable (default `PROJECT_NAME=example`)
- Volume mount a local directory as `/code` to save the Django project files to

```
docker run --rm \
  -e PROJECT_NAME=example \
  -v $(pwd):/code \
  mjstealey/django-startproject-docker
```

The above generates output files as a new Django project named `example`.

```console
$ tree example
example                         # Project root
├── Dockerfile                  # Dockerfile definition for django container
├── apps                        # Django apps directory
├── docker-compose.yml          # Compose definition for running web app
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
│   │   └── tasks.py            # Tasks Django settings file (intially blank)
│   ├── urls.py                 # Django urls file
│   └── wsgi.py                 # Django WSGI file
├── manage.py                   # Django manage.py file
├── plugins                     # Django plugins directory
│   └── __init__.py             # Python init
├── requirements.txt            # Pip install requirements file
├── run_uwsgi.sh                # uWSGI run script
└── uwsgi.ini                   # uWSGI configuration file 

4 directories, 21 files
```

On the first run a `static` directory will be created at the project root level and populated with the contents of the `admin` static files. The `media` directory would also be located at the project root level when it is used.

```console
example                         # Project root
├── media                       # Django static files
├── static                      # Django media files
... 
```

## Running your new project

The generated output includes all of the necessary files to start running your Django project locally, or in Docker.

**NOTE** - The default settings assume that a PostgreSQL database connection exists which is defined in the `docker-compose.yml` file. The user can change this by modifying the contents of `settings/config.py` to the database of their choosing.

## Run locally with Python 3

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

You will notice that two new directories have been created, `static` and `venv`.

- `static`: Collected static files from each of your applications (and any other places you specify) into a single location that can easily be served in production.
- `venv`: Python binary (allowing creation of environments with various Python versions) and can have its own independent set of installed Python packages in its site directories.


## Run everything in Docker

**Database**

The database is the same as in the above example.

**Django server**

Local files are shared with the `django` Docker container using a volume mount. Volume mounts are specified in the `docker-compose.yml` as follows

```yaml
volumes:
  - .:/code                 # Project root
  - ./static:/code/static   # Django static files
  - ./media:/code/media     # Django media files
```

Run using the docker-compose file 

```
cd example/
docker-compose up -d
```

Check the status of the containers

```console
$ docker-compose ps
  Name                Command              State                                  Ports
----------------------------------------------------------------------------------------------------------------------
database   docker-entrypoint.sh postgres   Up      0.0.0.0:5432->5432/tcp
django     /code/docker-entrypoint.sh      Up      0.0.0.0:8443->443/tcp, 0.0.0.0:8080->80/tcp, 0.0.0.0:8000->8000/tcp
```

Validate that your Django server is running at [http://localhost:8000/](http://localhost:8000/)

## Additional References

- Django docs: [https://docs.djangoproject.com/en/2.0/](https://docs.djangoproject.com/en/2.0/)
- Docker docs: [https://docs.docker.com](https://docs.docker.com)
- Docker Compose docs: [https://docs.docker.com/compose/](https://docs.docker.com/compose/)
