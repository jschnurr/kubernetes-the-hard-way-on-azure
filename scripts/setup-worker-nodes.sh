#!/bin/bash
# $1 total worker nodes

echo -e "\nStarted initialisation"
# load variables already set for the infrastructure
source azurerm-secret.tfvars

# determine location code from location
location_code=$(az account list-locations --query "[?displayName=='$location']".{Code:name} -o tsv)

# change current directory from infra
cd ../scripts/worker
echo "Completed initialisation"


# setup networking pre-requisites
echo -e "\nStarted setting up of networking pre-requisites"
for (( i=1; i<=$1; i++ ))
do
  # remote copy files
  echo "Copying files to $prefix-$environment-workervm0$i.$location_code.cloudapp.azure.com"
  scp -o "StrictHostKeyChecking no" 10-bridge.conf 99-loopback.conf \
    usr1@$prefix-$environment-workervm0$i.$location_code.cloudapp.azure.com:~

  # remote execute install script
  echo "Executing install script on $prefix-$environment-workervm0$i.$location_code.cloudapp.azure.com"
  ssh -o "StrictHostKeyChecking no" \
    usr1@$prefix-$environment-workervm0$i.$location_code.cloudapp.azure.com \
    'bash -s' < ../setup-networking-pre-requisites.sh $i
done
echo "Completed setting up of networking pre-requisites"


# setup container runtime
echo -e "\nStarted setting up of container runtime"
for (( i=1; i<=$1; i++ ))
do
  # remote copy files
  echo "Copying files to $prefix-$environment-workervm0$i.$location_code.cloudapp.azure.com"
  scp -o "StrictHostKeyChecking no" config.toml containerd.service \
    usr1@$prefix-$environment-workervm0$i.$location_code.cloudapp.azure.com:~

  # remote execute install script
  echo "Executing install script on $prefix-$environment-workervm0$i.$location_code.cloudapp.azure.com"
  ssh -o "StrictHostKeyChecking no" \
    usr1@$prefix-$environment-workervm0$i.$location_code.cloudapp.azure.com \
    'bash -s' < ../setup-container-runtime.sh
done
echo "Completed setting up of container runtime"


# setup kubernetes kubelet
echo -e "\nStarted setting up of kubernetes kubelet"
if [ ! -s configs/bootstrap-token.yaml ]
then
  echo "Creating bootstrap token yaml file"
  # copy the template bootstrap token yaml file
  cp bootstrap-token.yaml configs/bootstrap-token.yaml

  # substitute the value for <TOKEN_ID> with random 6 character alphanumeric string (0-9a-z)
  sed -i "s|<TOKEN_ID>|$(date +%N%s | sha256sum | head -c 6)|g" configs/bootstrap-token.yaml

  # substitute the value for <TOKEN_SECRET> with random 16 character alphanumeric string (0-9a-z)
  sed -i "s|<TOKEN_SECRET>|$(date +%N%s | sha256sum | head -c 16)|g" configs/bootstrap-token.yaml
fi

echo "Creating bootstrap token secret for kubelet"
# create bootstrap token secret
kubectl apply -f configs/bootstrap-token.yaml --kubeconfig configs/admin.kubeconfig

echo "Creating cluster role bindings for kubelet"
# create cluster role binding for kubelet to auto create csr
kubectl apply -f csr-for-bootstrapping.yaml --kubeconfig configs/admin.kubeconfig
# create cluster role binding for kubelet to auto approve csr
kubectl apply -f auto-approve-csrs-for-group.yaml --kubeconfig configs/admin.kubeconfig
# create cluster role binding for kubelet to auto renew certificates on expiration
kubectl apply -f auto-approve-renewals-for-nodes.yaml --kubeconfig configs/admin.kubeconfig

for (( i=1; i<=$1; i++ ))
do
  # remote copy files
  echo "Copying files to $prefix-$environment-workervm0$i.$location_code.cloudapp.azure.com"
  scp -o "StrictHostKeyChecking no" certs/ca.crt configs/bootstrap-kubeconfig kubelet-config.yaml kubelet.service \
    usr1@$prefix-$environment-workervm0$i.$location_code.cloudapp.azure.com:~

  # remote execute install script
  echo "Executing install script on $prefix-$environment-workervm0$i.$location_code.cloudapp.azure.com"
  ssh -o "StrictHostKeyChecking no" \
    usr1@$prefix-$environment-workervm0$i.$location_code.cloudapp.azure.com \
    'bash -s' < ../setup-kubelet.sh $i
done

# approve certificate signing request (csr) of worker node
echo "Approving certificate signing request (csr) of worker node"
# give time for worker node to register
sleep 5
# get pending csrs
csrs="$(kubectl get csr --kubeconfig configs/admin.kubeconfig | grep -oP '^\w+-\w+(?=.*Pending$)' | tr '\n' ' ')"
# approve the pending csrs
kubectl certificate approve $csrs --kubeconfig configs/admin.kubeconfig
echo "Completed setting up of kubernetes kubelet"


# setup kubernetes kube-proxy
echo -e "\nStarted setting up of kubernetes kube-proxy"
for (( i=1; i<=$1; i++ ))
do
  # remote copy files
  echo "Copying files to $prefix-$environment-workervm0$i.$location_code.cloudapp.azure.com"
  scp -o "StrictHostKeyChecking no" configs/kube-proxy.kubeconfig kube-proxy-config.yaml kube-proxy.service \
    usr1@$prefix-$environment-workervm0$i.$location_code.cloudapp.azure.com:~

  # remote execute install script
  echo "Executing install script on $prefix-$environment-workervm0$i.$location_code.cloudapp.azure.com"
  ssh -o "StrictHostKeyChecking no" \
    usr1@$prefix-$environment-workervm0$i.$location_code.cloudapp.azure.com \
    'bash -s' < ../setup-kube-proxy.sh
done
echo "Completed setting up of kubernetes kube-proxy"


# verify worker nodes setup after everything
echo -e "\nDisplaying 'kubectl get nodes' output"
kubectl get nodes --kubeconfig configs/admin.kubeconfig