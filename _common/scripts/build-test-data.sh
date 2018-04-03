#!/usr/bin/env bash

echo "This is for example only"
exit

#docker run -v ./var/certs:/certs ubuntu:16.04

docker run --rm -v ${PWD}/var/dhparam:/dhparam ubuntu:16.04 sh -c 'apt update; apt install -y openssl; openssl dhparam -out /dhparam/dhparam.pem 2048'

docker run --rm -v ${PWD}/var/certs:/certs -v ${PWD}/bin/development/create_self_signed_certs.sh:/create_self_signed_certs.sh ubuntu:16.04 sh -c 'apt update; apt install -y openssl; /create_self_signed_certs.sh -f asset-engine -p  /certs'
