#!/bin/bash
# $1 total master nodes

echo "Started initialisation"
# load variables already set for the infrastructure
source azurerm-secret.tfvars

# determine location code from location
location_code=$(az account list-locations --query "[?displayName=='$location']".{Code:name} -o tsv)

# change current directory from infra
cd ../scripts/master
echo "Completed initialisation"

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
# create encryption key config if not already existing
if [ ! -s configs/encryption-config.yaml ]
then
  echo "Creating encryption config file"
  # copy the template encryption config yaml file
  cp encryption-config.yaml configs/encryption-config.yaml

  # generate openssl encryption config yaml file by substituting encyrption key with random value
  sed -i "s|<ENCRYPTION_KEY>|$(head -c 32 /dev/urandom | base64)|g" configs/encryption-config.yaml
fi
for (( i=1; i<=$1; i++ ))
do
  # remote copy files
  echo "Copying files to $prefix-$environment-mastervm0$i.$location_code.cloudapp.azure.com"
  scp -o "StrictHostKeyChecking no" certs/ca.crt certs/ca.key certs/kube-apiserver* certs/service-account* certs/etcd* \
    configs/encryption-config.yaml kube-apiserver.service \
    usr1@$prefix-$environment-mastervm0$i.$location_code.cloudapp.azure.com:~

  # remote execute install script
  echo "Executing install script on $prefix-$environment-mastervm0$i.$location_code.cloudapp.azure.com"
  ssh -o "StrictHostKeyChecking no" \
    usr1@$prefix-$environment-mastervm0$i.$location_code.cloudapp.azure.com \
    'bash -s' < ../setup-kube-apiserver.sh $1
done

# add kube-apiserver user to system:kube-apiserver-to-kubelet role (new) for exec and port-forward operation access
echo "Adding kube-apiserver user to system:kube-apiserver-to-kubelet role (new) for exec and port-forward operation access"
kubectl apply -f kube-apiserver-to-kubelet.yaml --kubeconfig configs/admin.kubeconfig

# verify kube-apiserver
echo "Displaying 'kubectl get all --all-namespaces' output"
kubectl get all --all-namespaces --kubeconfig configs/admin.kubeconfig
echo "Completed setting up of kubernetes api server"


# setup kubernetes scheduler
echo "Started setting up of kubernetes scheduler"
for (( i=1; i<=$1; i++ ))
do
  # remote copy files
  echo "Copying files to $prefix-$environment-mastervm0$i.$location_code.cloudapp.azure.com"
  scp -o "StrictHostKeyChecking no" configs/kube-scheduler.kubeconfig kube-scheduler.service \
    usr1@$prefix-$environment-mastervm0$i.$location_code.cloudapp.azure.com:~

  # remote execute install script
  echo "Executing install script on $prefix-$environment-mastervm0$i.$location_code.cloudapp.azure.com"
  ssh -o "StrictHostKeyChecking no" \
    usr1@$prefix-$environment-mastervm0$i.$location_code.cloudapp.azure.com \
    'bash -s' < ../setup-kube-scheduler.sh
done
echo "Completed setting up of kubernetes scheduler"

# setup kubernetes controller manager


# setup http health checks