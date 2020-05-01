#!/bin/bash
# $1 total master nodes

echo -e "\nStarted initialisation"
# load variables already set for the infrastructure
source azurerm-secret.tfvars

# determine location code from location
location_code=$(az account list-locations --query "[?displayName=='$location']".{Code:name} -o tsv)

# change current directory from infra
cd ../scripts/master
echo "Completed initialisation"

# setup http health check endpoint
echo -e "\nStarted setting up of http health check endpoint"
for (( i=1; i<=$1; i++ ))
do
  # remote copy files
  echo "Copying files to $prefix-$environment-mastervm0$i.$location_code.cloudapp.azure.com"
  scp -o "StrictHostKeyChecking no" healthprobe \
    usr1@$prefix-$environment-mastervm0$i.$location_code.cloudapp.azure.com:~

  # remote execute install script
  echo "Executing install script on $prefix-$environment-mastervm0$i.$location_code.cloudapp.azure.com"
  ssh -o "StrictHostKeyChecking no" \
    usr1@$prefix-$environment-mastervm0$i.$location_code.cloudapp.azure.com \
    'bash -s' < ../setup-nginx.sh
done
echo "Completed setting up of http health check endpoint"