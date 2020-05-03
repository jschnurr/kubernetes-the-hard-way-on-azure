#!/bin/bash
# locally executed script assumes the current/execution directory:
# "cd ~/kthw-azure-git/infra"

# load variables already set for the infrastructure
source azurerm-secret.tfvars

echo -e "\nSetting up all master nodes of count - $master_vm_count"
../scripts/setup-master-nodes.sh $master_vm_count

echo -e "\nSetting up all worker nodes of count - $worker_vm_count"
../scripts/setup-worker-nodes.sh $worker_vm_count