#!/bin/bash
# locally executed script assumes the current/execution directory:
# "cd ~/kthw-azure-git/infra"
# $1 - total master nodes

echo -e "\nStarted initialisation"
# load variables already set for the infrastructure
source azurerm-secret.tfvars

# determine location code from location
location_code=$(az account list-locations --query "[?displayName=='$location']".{Code:name} -o tsv)

# change current directory from infra
cd ../scripts/master

# modify user permissions to execute all shell scripts
chmod +x ../*.sh

# create certificates, if not already existing

# create a directory to hold all the generated certificates
if [ ! -d certs ]
then
  mkdir certs
fi

# create ca certificate
is_new_ca=false
if [ ! -s certs/ca.crt ] || [ ! -s certs/ca.key ]
then
  is_new_ca=true
  ../gen-ca-cert.sh ca "/CN=KUBERNETES-CA"

  rm ../worker/certs/ca.* -f
fi

# create admin client certificate
if ( $is_new_ca ) || [ ! -s certs/admin.crt ] || [ ! -s certs/admin.key ]
then
  ../gen-simple-cert.sh admin ca "/CN=admin/O=system:masters"
fi

# create kube-scheduler client certificate
if ( $is_new_ca ) || [ ! -s certs/kube-scheduler.crt ] || [ ! -s certs/kube-scheduler.key ]
then
  ../gen-simple-cert.sh kube-scheduler ca "/CN=system:kube-scheduler"
fi

# create kube-controller-manager client certificate
if ( $is_new_ca ) || [ ! -s certs/kube-controller-manager.crt ] || [ ! -s certs/kube-controller-manager.key ]
then
  ../gen-simple-cert.sh kube-controller-manager ca "/CN=system:kube-controller-manager"
fi

# create service account key pair certificate
if ( $is_new_ca ) || [ ! -s certs/service-account.crt ] || [ ! -s certs/service-account.key ]
then
  ../gen-simple-cert.sh service-account ca "/CN=service-accounts"
fi

# create etcd server certificate
if ( $is_new_ca ) || [ ! -s certs/etcd-server.crt ] || [ ! -s certs/etcd-server.key ]
then
  ../gen-advanced-cert.sh etcd-server ca "/CN=etcd-server" openssl-etcd
fi

# create kube-apiserver certificate
if ( $is_new_ca ) || [ ! -s certs/kube-apiserver.crt ] || [ ! -s certs/kube-apiserver.key ]
then
  # copy the template openssl config file
  cp openssl-kube-apiserver.cnf openssl-kube-apiserver-secret.cnf

  # generate openssl configuration file for your environment
  sed -i "s|<PREFIX>|$prefix|g; s|<ENVIRONMENT>|$environment|g; s|<LOCATION_CODE>|$location_code|g" openssl-kube-apiserver-secret.cnf

  # generate certificate passing the openssl configuration generated from last step
  ../gen-advanced-cert.sh kube-apiserver ca "/CN=kube-apiserver" openssl-kube-apiserver-secret
fi

# create kubernetes configurations, if not already existing

# create a directory to hold all the generated certificates
if [ ! -d configs ]
then
  mkdir configs
fi

# create admin kube config file
if [ ! -s configs/admin.kubeconfig ]
then
  ../gen-kube-config.sh kubernetes-the-hard-way-azure \
    certs/ca \
    "https://$prefix-$environment-apiserver.$location_code.cloudapp.azure.com:6443" \
    configs/admin \
    admin \
    certs/admin
fi

# create kube-scheduler kube config file
if [ ! -s configs/kube-scheduler.kubeconfig ]
then
  ../gen-kube-config.sh kubernetes-the-hard-way-azure \
    certs/ca \
    "https://$prefix-$environment-apiserver.$location_code.cloudapp.azure.com:6443" \
    configs/kube-scheduler \
    system:kube-scheduler \
    certs/kube-scheduler
fi

# create kube-controller-manager kube config file
if [ ! -s configs/kube-controller-manager.kubeconfig ]
then
  ../gen-kube-config.sh kubernetes-the-hard-way-azure \
    certs/ca \
    "https://$prefix-$environment-apiserver.$location_code.cloudapp.azure.com:6443" \
    configs/kube-controller-manager \
    system:kube-controller-manager \
    certs/kube-controller-manager
fi

# create encryption key config file
if [ ! -s configs/encryption-config.yaml ]
then
  # copy the template encryption config yaml file
  cp encryption-config.yaml configs/encryption-config.yaml

  # generate openssl encryption config yaml file by substituting encyrption key with random value
  sed -i "s|<ENCRYPTION_KEY>|$(date +%N%s | sha256sum | head -c 32 | base64)|g" configs/encryption-config.yaml
fi
echo "Completed initialisation"

# setup etcd server
echo -e "\nStarted setting up of etcd server"
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
echo -e "\nStarted setting up of kubernetes api server"
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
echo "Completed setting up of kubernetes api server"


# setup kubernetes scheduler
echo -e "\nStarted setting up of kubernetes scheduler"
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
echo -e "\nStarted setting up of kubernetes controller manager"
for (( i=1; i<=$1; i++ ))
do
  # remote copy files
  echo "Copying files to $prefix-$environment-mastervm0$i.$location_code.cloudapp.azure.com"
  scp -o "StrictHostKeyChecking no" configs/kube-controller-manager.kubeconfig kube-controller-manager.service \
    usr1@$prefix-$environment-mastervm0$i.$location_code.cloudapp.azure.com:~

  # remote execute install script
  echo "Executing install script on $prefix-$environment-mastervm0$i.$location_code.cloudapp.azure.com"
  ssh -o "StrictHostKeyChecking no" \
    usr1@$prefix-$environment-mastervm0$i.$location_code.cloudapp.azure.com \
    'bash -s' < ../setup-kube-controller-manager.sh
done
echo "Completed setting up of kubernetes controller manager"

# give time for kube-apiserver to warmup
echo "Sleeping to give time for kube-apiserver to warmup"
sleep 20

# verify kube-apiserver
echo "Displaying 'kubectl get all --all-namespaces' output"
kubectl get all --all-namespaces --kubeconfig configs/admin.kubeconfig

# add kube-apiserver user to system:kube-apiserver-to-kubelet role (new) for exec and port-forward operation access
echo "Adding kube-apiserver user to system:kube-apiserver-to-kubelet role (new) for exec and port-forward operation access"
kubectl apply -f kube-apiserver-to-kubelet.yaml --kubeconfig configs/admin.kubeconfig

# verify master nodes setup after everything
echo -e "\nDisplaying 'kubectl get componentstatuses' output"
kubectl get componentstatuses --kubeconfig configs/admin.kubeconfig