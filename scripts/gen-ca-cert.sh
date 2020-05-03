#!/bin/bash
# locally executed script assumes the current/execution directory:
# "cd ~/kthw-azure-git/scripts/master" or "cd ~/kthw-azure-git/scripts/worker"
# $1 - ca certificate file name w/o extension
# $2 - ca subject

# create private key
openssl genrsa -out certs/$1.key 2048

# create certificate signing request (csr) using private key
openssl req -new -key certs/$1.key -subj "$2" -out certs/$1.csr

# self sign csr using own private key
openssl x509 -req -in certs/$1.csr -signkey certs/$1.key -CAcreateserial -out certs/$1.crt -days 1000

# delete csr
rm certs/$1.csr