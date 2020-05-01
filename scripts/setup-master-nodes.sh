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
echo "Started setting up of etcd server"
for (( i=$1; i>=1; i-- ))
do
  # remote copy files
  echo "Copying files to $prefix-$environment-mastervm0$i.$location_code.cloudapp.azure.com"
  scp -o "StrictHostKeyChecking no" certs/ca.crt certs/etcd* etcd.service \
    usr1@$prefix-$environment-mastervm0$i.$location_code.cloudapp.azure.com:~

  # remote execute install script
  echo "Executing install script on $prefix-$environment-mastervm0$i.$location_code.cloudapp.azure.com"
  ssh -o "StrictHostKeyChecking no" \
    usr1@$prefix-$environment-mastervm0$i.$location_code.cloudapp.azure.com \
    'bash -s' < ../setup-etcd.sh $1 $i $prefix $environment
done
echo "Completed setting up of etcd server"


# setup kubernetes api server
echo "Started setting up of kubernetes api server"
for (( i=$1; i>=1; i-- ))
do
  # remote copy files
  echo "Copying files to $prefix-$environment-mastervm0$i.$location_code.cloudapp.azure.com"
  scp -o "StrictHostKeyChecking no" certs/ca.crt certs/ca.key certs/kube-apiserver* certs/service-account* certs/etcd* \
    usr1@$prefix-$environment-mastervm0$i.$location_code.cloudapp.azure.com:~

  # remote execute install script
  echo "Executing install script on $prefix-$environment-mastervm0$i.$location_code.cloudapp.azure.com"
  ssh -o "StrictHostKeyChecking no" \
    usr1@$prefix-$environment-mastervm0$i.$location_code.cloudapp.azure.com \
    'bash -s' < ../setup-kube-apiserver.sh $1 $i $prefix $environment
done
echo "Completed setting up of kubernetes api server"


# setup kubernetes scheduler


# setup kubernetes controller manager


# setup http health checks