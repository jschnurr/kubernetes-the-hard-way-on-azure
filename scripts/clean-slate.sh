#!/bin/bash
# locally executed script assumes the current/execution directory:
# "cd ~/kthw-azure-git/infra"
# $1 - enable certificates & terraform state cleanup

if [ -s terraform.tfstate ]
then
  echo -e "\nTerraform destroy"
  terraform destroy -auto-approve -var-file=azurerm-secret.tfvars
fi

echo -e "\nDeleting configs and secrets inside scripts/master & scripts/worker"
rm ../scripts/master/configs ../scripts/master/*secret* \
  ../scripts/worker/configs ../scripts/worker/*secret* -rf

if [ ! -z "$1" ] && ( $1 )
then
  echo -e "\nDeleting certs inside scripts/master & scripts/worker"
  rm ../scripts/master/certs ../scripts/worker/certs -rf

  echo -e "\nDeleting terraform state"
  rm terraform.tfstate* -rf

  echo -e "\nDeleting terraform providers"
  rm .terraform -rf
fi