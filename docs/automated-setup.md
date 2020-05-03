# Automated scale and end to end provisioning

Once you have setup the kubernetes by hand, it is time to explore the other avenues in this tutorial project to achieve the same with one line commands.


## Initialisation
```
cd ~/kthw-azure-git/infra

# load variables already set for the infrastructure
source azurerm-secret.tfvars

# determine location code from location
location_code=$(az account list-locations --query "[?displayName=='$location']".{Code:name} -o tsv)

# modify user permissions to execute all shell scripts
cd ~/kthw-azure-git/scripts
chmod +x *.sh
```


## Scale out / increase count of master nodes
```
cd ~/kthw-azure-git/infra

# set the variable - 'master_vm_count' value to 2 or as per your desire but keep it below 6 as 5 master node configuration gives enough fault tolerance
sed -i 's|^master_vm_count.*$|master_vm_count=2|g' azurerm-secret.tfvars

# set the variable - 'enable_master_setup' value to true
sed -i 's|^enable_master_setup.*$|enable_master_setup=true|g' azurerm-secret.tfvars

# set the variable - 'enable_health_probe' value as true, if not already
sed -i 's|^enable_health_probe.*$|enable_health_probe=true|g' azurerm-secret.tfvars

# execute the god mode script to perform one command provisioning and then automatic installation of both master and worker nodes
../scripts/auto-provision.sh

# note that this automated script execution will go through all the master nodes (first) and worker nodes (second) and try minor repairs along the way if it is found to be installed already
```


## Scale out / increase count of worker nodes
```
cd ~/kthw-azure-git/infra

# set the variable - 'worker_vm_count' value to 2 or as per your desire but keep it below 10 as this tutorial project is having this limitation of maximum 9 worker nodes unless you are okay to modify certain terraform scripts w.r.t route table entries and naming convention of virtual machines
sed -i 's|^worker_vm_count.*$|worker_vm_count=2|g' azurerm-secret.tfvars

# set the variable - 'enable_worker_setup' value to true
sed -i 's|^enable_worker_setup.*$|enable_worker_setup=true|g' azurerm-secret.tfvars

# execute the god mode script to perform one command provisioning and then automatic installation of both master and worker nodes
../scripts/auto-provision.sh

# note that this automated script execution will go through all the master nodes (first) and worker nodes (second) and try minor repairs along the way if it is found to be installed already
```


## Scale up / size up any nodes
```
cd ~/kthw-azure-git/infra

# set the variable - 'master_vm_size' or 'worker_vm_size' value as per your desire but keep a minimum of 2gb ram for master node to function properly
# run this to know more: "az vm list-sizes --location "$location" -o table"
sed -i 's|^master_vm_size.*$|master_vm_size=VALUE|g' azurerm-secret.tfvars
sed -i 's|^worker_vm_size.*$|worker_vm_size=VALUE|g' azurerm-secret.tfvars

# set the variable - 'enable_master_setup' value to true
sed -i 's|^enable_master_setup.*$|enable_master_setup=true|g' azurerm-secret.tfvars

# set the variable - 'enable_worker_setup' value to true
sed -i 's|^enable_worker_setup.*$|enable_worker_setup=true|g' azurerm-secret.tfvars

# execute the god mode script to perform one command provisioning and then automatic installation of both master and worker nodes
../scripts/auto-provision.sh

# note that this automated script execution will go through all the master nodes (first) and worker nodes (second) and try minor repairs along the way if it is found to be installed already
```


## Manually trigger automated installation scripts
```
cd ~/kthw-azure-git/infra

# if in case you have scaled out master and/or worker nodes without the variable 'enable_master_setup' and/or 'enable_worker_setup' set to true, then you have the following option
../scripts/auto-setup.sh

# note that this script will not provision any new nodes but will automatically install all master and worker nodes regardless of the said variable value
```


## Fully automated end to end provisioning

As you may have guessed that this tutorial project allows you to fully provision a kubernetes cluster from the very beginning. To meet this end, you can start again with a blank slate by following the [cleanup](cleanup.md) instructions.

```
cd ~/kthw-azure-git/infra

# set the variable - 'enable_health_probe' value as true
sed -i 's|^enable_health_probe.*$|enable_health_probe=true|g' azurerm-secret.tfvars

# set the variable - 'enable_master_setup' value to true
sed -i 's|^enable_master_setup.*$|enable_master_setup=true|g' azurerm-secret.tfvars

# set the variable - 'enable_worker_setup' value to true
sed -i 's|^enable_worker_setup.*$|enable_worker_setup=true|g' azurerm-secret.tfvars

# execute the god mode script to perform one command provisioning and then automatic installation of both master and worker nodes
../scripts/auto-provision.sh

# pass an argument with filename and its path to capture the log output from the execution of the script like this:
../scripts/auto-provision.sh ~/log.txt
```


## IMPORTANT NOTE if you are scaling down / decreasing count of master nodes

Master nodes contain etcd distributed key-value store which works on quorum and it can be easily broken (corrupted) if you scale down without removing the etcd member from the etcd cluster first.

```
# remote login to mastervm01
ssh usr1@$prefix-$environment-mastervm01.$location_code.cloudapp.azure.com

cd ~

# find the member id as <MEMBER_ID> in the first column for the master node which is last in serial number
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.crt \
  --cert=/etc/etcd/etcd-server.crt \
  --key=/etc/etcd/etcd-server.key

# remove the last master node from the member list
echo "Removing existing etcd member - $3-$4-mastervm0$i"
sudo ETCDCTL_API=3 etcdctl member remove \
  <MEMBER_ID> \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.crt \
  --cert=/etc/etcd/etcd-server.crt \
  --key=/etc/etcd/etcd-server.key

# remote logout from mastervm01
logout
```