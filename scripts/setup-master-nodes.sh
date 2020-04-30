#!/bin/bash
# $1 total master nodes
# $2 create certificates?
# $3 create kubernetes configurations?

# initialise variables set for the infrastructure
source azurerm-secret.tfvars

# determine location code from location
location_code=$(az account list-locations --query "[?displayName=='$location']".{Code:name} -o tsv)

cd ../scripts/master

# setup etcd server
for (( i=$1; i>=1; i-- ))
do
  # remote copy files
  scp certs/ca.crt certs/etcd* etcd.service \
    usr1@$prefix-$environment-mastervm0$i.$location_code.cloudapp.azure.com:~

  # remote execute install script
  ssh -o "StrictHostKeyChecking no" \
    usr1@$prefix-$environment-mastervm0$i.$location_code.cloudapp.azure.com \
    'bash -s' < ../setup-etcd.sh $1 $i $prefix $environment
done