#!/bin/sh
#
# check if docker is running

GUACAMOLE_VERSION=1.5.5

if ! (docker ps >/dev/null 2>&1)
then
	echo "docker daemon not running, will exit here!"
	exit
fi
echo "Preparing folder init and creating ./init/initdb.sql"
mkdir ./init >/dev/null 2>&1
docker run --rm guacamole/guacamole:${GUACAMOLE_VERSION} /opt/guacamole/bin/initdb.sh --postgresql > ./init/initdb.sql
chmod -R +x ./init
echo "done"

echo "Creating SSL certificates"
mkdir -p ./nginx/ssl >/dev/null 2>&1
openssl req -nodes -newkey rsa:2048 -new -x509 -keyout nginx/ssl/self-ssl.key -out nginx/ssl/self.cert -subj '/C=DE/ST=BY/L=Hintertupfing/O=Dorfwirt/OU=Theke/CN=www.createyourown.domain/emailAddress=docker@createyourown.domain'
echo "You can use your own certificates by placing the private key in nginx/ssl/self-ssl.key and the cert in nginx/ssl/self.cert"
echo "done"
