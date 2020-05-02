#!/bin/bash
# locally executed script assumes the current/execution directory:
# "cd ~/kthw-azure-git/scripts/master" or "cd ~/kthw-azure-git/scripts/worker"
# $1 - target certificate file name w/o extension
# $2 - ca key file name w/o extension
# $3 - subject

# create private key
openssl genrsa -out certs/$1.key 2048

# create certificate signing request (csr) using private key
openssl req -new -key certs/$1.key -subj "$3" -out certs/$1.csr

# sign csr using ca private key
openssl x509 -req -in certs/$1.csr -CA certs/$2.crt -CAkey certs/$2.key -CAcreateserial -out certs/$1.crt -days 1000

# delete csr
rm certs/$1.csr