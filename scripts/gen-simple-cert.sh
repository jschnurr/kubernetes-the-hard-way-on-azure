#!/bin/bash
# $1 = target certificate
# $2 = ca key
# $3 = subject

# create private key
openssl genrsa -out certs/$1.key 2048

# create certificate signing request (csr) using private key
openssl req -new -key certs/$1.key -subj "$3" -out certs/$1.csr

# sign csr using ca private key
openssl x509 -req -in certs/$1.csr -CA certs/$2.crt -CAkey certs/$2.key -CAcreateserial -out certs/$1.crt -days 1000

# delete csr
rm certs/$1.csr