# Guacamole with docker compose
This is a small documentation how to run a fully working **Apache Guacamole (incubating)** instance with docker (docker compose). The goal of this project is to make it easy to test Guacamole.

## About Guacamole
Apache Guacamole (incubating) is a clientless remote desktop gateway. It supports standard protocols like VNC, RDP, and SSH. It is called clientless because no plugins or client software are required. Thanks to HTML5, once Guacamole is installed on a server, all you need to access your desktops is a web browser.

It supports RDP, SSH, Telnet and VNC and is the fastest HTML5 gateway I know. Checkout the projects [homepage](https://guacamole.incubator.apache.org/) for more information.

## Prerequisites
You need a working **docker** installation and **docker compose** running on your machine.

## Quick start
Clone the GIT repository and start guacamole:

~~~bash
git clone "https://github.com/boschkundendienst/guacamole-docker-compose.git"
cd guacamole-docker-compose
./prepare.sh
docker compose up -d
~~~

Your guacamole server should now be available at `https://ip of your server:8443/`. The default username is `guacadmin` with password `guacadmin`.

## Details
To understand some details let's take a closer look at parts of the `docker-compose.yml` file:

### Networking
The following part of docker-compose.yml will create a network with name `guacnetwork_compose` in mode `bridged`.
~~~python
...
# networks
# create a network 'guacnetwork_compose' in mode 'bridged'
networks:
  guacnetwork_compose:
    driver: bridge
...
~~~

### Services
#### guacd
The following part of docker-compose.yml will create the guacd service. guacd is the heart of Guacamole which dynamically loads support for remote desktop protocols (called "client plugins") and connects them to remote desktops based on instructions received from the web application. The container will be called `guacd_compose` based on the docker image `guacamole/guacd` connected to our previously created network `guacnetwork_compose`. Additionally we map the 2 local folders `./drive` and `./record` into the container. We can use them later to map user drives and store recordings of sessions.

~~~python
...
services:
  # guacd
  guacd:
    container_name: guacd_compose
    image: guacamole/guacd
    networks:
      guacnetwork_compose:
    restart: always
    volumes:
    - ./drive:/drive:rw
    - ./record:/record:rw
...
~~~

#### PostgreSQL
The following part of docker-compose.yml will create an instance of PostgreSQL using the official docker image. This image is highly configurable using environment variables. It will for example initialize a database if an initialization script is found in the folder `/docker-entrypoint-initdb.d` within the image. Since we map the local folder `./init` inside the container as `docker-entrypoint-initdb.d` we can initialize the database for guacamole using our own script (`./init/initdb.sql`). You can read more about the details of the official postgres image [here](http://).

~~~python
...
  postgres:
    container_name: postgres_guacamole_compose
    environment:
      PGDATA: /var/lib/postgresql/data/guacamole
      POSTGRES_DB: guacamole_db
      POSTGRES_PASSWORD: ChooseYourOwnPasswordHere1234
      POSTGRES_USER: guacamole_user
    image: postgres
    networks:
      guacnetwork_compose:
    restart: always
    volumes:
    - ./init:/docker-entrypoint-initdb.d:ro
    - ./data:/var/lib/postgresql/data:rw
...
~~~

#### Guacamole
The following part of docker-compose.yml will create an instance of guacamole by using the docker image `guacamole` from docker hub. It is also highly configurable using environment variables. In this setup it is configured to connect to the previously created postgres instance using a username and password and the database `guacamole_db`. Port 8080 is only exposed locally! We will attach an instance of nginx for public facing of it in the next step.

~~~python
...
  guacamole:
    container_name: guacamole_compose
    depends_on:
    - guacd
    - postgres
    environment:
      GUACD_HOSTNAME: guacd
      POSTGRES_DATABASE: guacamole_db
      POSTGRES_HOSTNAME: postgres
      POSTGRES_PASSWORD: ChooseYourOwnPasswordHere1234
      POSTGRES_USER: guacamole_user
    image: guacamole/guacamole
    links:
    - guacd
    networks:
      guacnetwork_compose:
    ports:
    - 8080/tcp
    restart: always
...
~~~

#### nginx
The following part of docker-compose.yml will create an instance of nginx that maps the public port 8443 to the internal port 443. The internal port 443 is then mapped to guacamole using the `./nginx/templates/guacamole.conf.template` file. The container will use the previously generated (`prepare.sh`) self-signed certificate in `./nginx/ssl/` with `./nginx/ssl/self-ssl.key` and `./nginx/ssl/self.cert`.

~~~python
...
  # nginx
  nginx:
   container_name: nginx_guacamole_compose
   restart: always
   image: nginx
   volumes:
   - ./nginx/templates:/etc/nginx/templates:ro
   - ./nginx/ssl/self.cert:/etc/nginx/ssl/self.cert:ro
   - ./nginx/ssl/self-ssl.key:/etc/nginx/ssl/self-ssl.key:ro
   ports:
   - 8443:443
   links:
   - guacamole
   networks:
     guacnetwork_compose:
...
~~~

## prepare.sh
`prepare.sh` is a small script that creates `./init/initdb.sql` by downloading the docker image `guacamole/guacamole` and start it like this:

~~~bash
docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --postgresql > ./init/initdb.sql
~~~

It creates the necessary database initialization file for postgres.

`prepare.sh` also creates the self-signed certificate `./nginx/ssl/self.cert` and the private key `./nginx/ssl/self-ssl.key` which are used
by nginx for https.

## reset.sh
To reset everything to the beginning, just run `./reset.sh`.

## WOL

Wake on LAN (WOL) does not work and I will not fix that because it is beyound the scope of this repo. But [zukkie777](https://github.com/zukkie777) who also filed [this issue](https://github.com/boschkundendienst/guacamole-docker-compose/issues/12) fixed it. You can read about it on the [Guacamole mailing list](http://apache-guacamole-general-user-mailing-list.2363388.n4.nabble.com/How-to-docker-composer-for-WOL-td9164.html)

**Disclaimer**

Downloading and executing scripts from the internet may harm your computer. Make sure to check the source of the scripts before executing them!

# docker-compose file for Apache Guacamole

```md
####################################################################################
# docker-compose file for Apache Guacamole
 created by PCFreak 2017-06-28

Apache Guacamole is a clientless remote desktop gateway. It supports standard
protocols like VNC, RDP, and SSH. We call it clientless because no plugins or
client software are required. Thanks to HTML5, once Guacamole is installed on
a server, all you need to access your desktops is a web browser.

####################################################################################

 What does this file do?

 Using docker-compose it will:

 - create a network 'guacnetwork_compose' with the 'bridge' driver.
 - create a service 'guacd_compose' from 'guacamole/guacd' connected to 'guacnetwork_compose'
 - create a service 'postgres_guacamole_compose' (1) from 'postgres' connected to 'guacnetwork_compose'
 - create a service 'guacamole_compose' (2)  from 'guacamole/guacamole/' conn. to 'guacnetwork_compose'
 - create a service 'nginx_guacamole_compose' (3) from 'nginx' connected to 'guacnetwork_compose'

 (1)
  DB-Init script is in './init/initdb.sql' it has been created executing
  'docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --postgresql > ./init/initdb.sql'
  once.
  DATA-DIR       is in './data'
  If you want to change the DB password change all lines with 'POSTGRES_PASSWORD:' and
  change it to your needs before first start.
  To start from scratch delete './data' dir completely
  './data' will hold all data after first start!
  The initdb.d scripts are only executed the first time the container is started
  (and the database files are empty). If the database files already exist then the initdb.d
  scripts are ignored (e.g. when you mount a local directory or when docker-compose saves
  the volume and reuses it for the new container).

  !!!!! MAKE SURE your folder './init' is executable (chmod +x ./init)
  !!!!! or 'initdb.sql' will be ignored!

  './data' will hold all data after first start!

 (2)
  Make sure you use the same value for 'POSTGRES_USER' and 'POSTGRES_PASSWORD'
  as configured under (1)

 (3)
  ./nginx/templates folder will be mapped read-only into the container at /etc/nginx/templates
  and according to the official nginx container docs the guacamole.conf.template will be
  placed in /etc/nginx/conf.d/guacamole.conf after container startup.
  ./nginx/ssl will be mapped into the container at /etc/nginx/ssl
  prepare.sh creates a a self-signed certificate. If you want to use your own certs
  just remove the part that generates the certs from prepare.sh and replace
  'self-ssl.key' and 'self.cert' with your certificate.
  nginx will export port 8443 to the outside world, make sure that this port is reachable
  on your system from the "outside world". All other traffic is only internal.

  You could remove the entire 'nginx' service from this file if you want to use your own
  reverse proxy in front of guacamole. If doing so, make sure you change the line
   from     - 8080/tcp
   to       - 8080:8080/tcp
  within the 'guacamole' service. This will expose the guacamole webinterface directly
  on port 8080 and you can use it for your own purposes.
  Note: Guacamole is available on :8080/guacamole, not /.

 !!!!! FOR INITAL SETUP (after git clone) run ./prepare.sh once

 !!!!! FOR A FULL RESET (WILL ERASE YOUR DATABASE, YOUR FILES, YOUR RECORDS AND CERTS) DO A
 !!!!!  ./reset.sh


 The initial login to the guacamole webinterface is:

     Username: guacadmin
     Password: guacadmin

 Make sure you change it immediately!

 version            date              comment
 0.1                2017-06-28        initial release
 0.2                2017-10-09        minor fixes + internal GIT push
 0.3                2017-10-09        minor fixes + public GIT push
 0.4                2019-08-14        creating of ssl certs now in prepare.sh
                                      simplified nginx startup commands
 0.5                2023-02-24        nginx now uses a template + some minor changes
 0.6                2023-03-23        switched to postgres 15.2-alpine
 0.61               2024-07-27        fix networks + version 3.0
 0.62               2024-07-27        fix
#####################################################################################
```