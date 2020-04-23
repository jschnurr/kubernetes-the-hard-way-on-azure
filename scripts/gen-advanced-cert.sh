#!/bin/bash
# $1 = target certificate
# $2 = ca key
# $3 = subject
# $4 = openssl config

# create private key
openssl genrsa -out certs/$1.key 2048

# create csr using private key
openssl req -new -key certs/$2.key -subj "$3" -out certs/$1.csr -config $4.cnf

# sign the csr using ca private key
openssl x509 -req -in certs/$1.csr -CA certs/$2.crt -CAkey certs/$2.key -CAcreateserial -out certs/$1.crt -days 1000 -extensions v3_req -extfile $4.cnf

# delete the csr
rm certs/$1.csr