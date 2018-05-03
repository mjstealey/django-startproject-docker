# Django startproject in Docker

Generates the necessary files to start a new Django project using Docker based scripts.

- Python 3.6 base Docker definition ([python:3.6](https://hub.docker.com/_/python/))
- Virtual environment managed by venv ([module venv](https://docs.python.org/3/library/venv.html#module-venv))
- PostgreSQL database adapter ([psycopg2-binary](https://pypi.org/project/psycopg2-binary/))
- uWSGI based run script ([uWGSI](https://pypi.org/project/uWSGI/))
- python-dotenv app settings management ([python-dotenv](https://pypi.org/project/python-dotenv/))
- Extended User Model with **base**, **home**, **login**, and **signup** templates (inspired by [Django: How to Extend The User Model (aka Custom User Model)](https://wsvincent.com/django-custom-user-model-tutorial/))

Project files are designed to be run either locally using venv, or in Docker using the generated `docker-compose.yml` file.

## Start a new project

Build the Dockerfile

```
docker build -t django-startproject .
```

Run the `django-startproject` image:

- Set the project name using `PROJECT_NAME` (default `PROJECT_NAME=example`)
- Save the output to a local directory by mounting it as `/code`

```
docker run --rm \
  -e PROJECT_NAME=example \
  -v $(pwd):/code \
  django-startproject
```

The output is a new Django project named `example`.

```console
$ tree -a example
example
├── Dockerfile
├── docker-compose.yml
├── docker-entrypoint.sh
├── example
│   ├── .env
│   ├── __init__.py
│   ├── secrets.py
│   ├── settings.py
│   ├── urls.py
│   └── wsgi.py
├── manage.py
├── requirements.txt
├── run_uwsgi.sh
├── users
│   ├── __init__.py
│   ├── admin.py
│   ├── apps.py
│   ├── forms.py
│   ├── migrations
│   │   ├── 0001_initial.py
│   │   └── __init__.py
│   ├── models.py
│   ├── templates
│   │   ├── base.html
│   │   ├── home.html
│   │   ├── registration
│   │   │   └── login.html
│   │   └── signup.html
│   ├── tests.py
│   ├── urls.py
│   └── views.py
└── uwsgi.ini

5 directories, 27 files
```

## Running your new project

The generated output includes all of the necessary files to start running your Django project locally, or in Docker.

**NOTE** - The default output assumes a PostgreSQL database connection which is defined in the `docker-compose.yml` file. The user can change this by modifying the contents of `secrets.py` to the database of their choosing.

### Local

**Database**

Start the database.

```
cd example/
docker-compose up -d database
```

Validate the database container is running.

```console
$ docker-compose ps
  Name                Command              State           Ports
-------------------------------------------------------------------------
database   docker-entrypoint.sh postgres   Up      0.0.0.0:5432->5432/tcp
```

**Django server**

Run locally using venv.

```
$ python3 -m venv venv
$ source venv/bin/activate
(venv)$ pip install --upgrade pip
(venv)$ pip install -r requirements.txt
(venv)$ ./run_uwsgi.sh
```

Validate that Django is running site at [http://localhost:8000/](http://localhost:8000/) where you should see the `home.html` page. (A simple, but functional home page at the sites root)

Included template pages:

- `home.html` at [http://localhost:8000/](http://localhost:8000/)
  <img width="80%" alt="home.html" src="https://user-images.githubusercontent.com/5332509/39598329-2b1b5298-4ee6-11e8-9f36-afe2832cfd31.png">

- `login.html` at [http://localhost:8000/users/login/](http://localhost:8000/users/login/)
  <img width="80%" alt="login.html" src="https://user-images.githubusercontent.com/5332509/39598562-f0fe5fbe-4ee6-11e8-9c16-cd6757b097cf.png">

- `signup.html`at [http://localhost:8000/users/signup/](http://localhost:8000/users/signup/)
  <img width="80%" alt="signup.html" src="https://user-images.githubusercontent.com/5332509/39598561-f0d3cad8-4ee6-11e8-9afd-cfe7105b0d05.png">

You should also notice that two new directories have been created, `static` and `venv`.

- `static`: Collected static files from each of your applications (and any other places you specify) into a single location that can easily be served in production.
- `venv`: Python binary (allowing creation of environments with various Python versions) and can have its own independent set of installed Python packages in its site directories.


### Docker

Local files are first copied to the Docker container and any locally generated files in `venv`, `static` or `images` are purged from Docker's copy prior to building.

Run the docker-compose file 

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

Validate that Django is running site at [http://localhost:8000/](http://localhost:8000/)

## Additional References

- Django docs: [https://docs.djangoproject.com/en/2.0/](https://docs.djangoproject.com/en/2.0/)
- Docker docs: [https://docs.docker.com](https://docs.docker.com)
- Docker Compose docs: [https://docs.docker.com/compose/](https://docs.docker.com/compose/)
