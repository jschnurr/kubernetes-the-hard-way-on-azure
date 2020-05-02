#!/bin/bash
# locally executed script assumes the current/execution directory:
# "cd ~/kthw-azure-git/infra"
# $1 - enable certificates, configurations & terraform state cleanup

if [ -s terraform.tfstate ]
then
  echo "Terraform destroy"
  terraform destroy -auto-approve -var-file=azurerm-secret.tfvars
fi

if [ ! -z "$1" ] && ( $1 )
then
  echo "Deleting certs and configs"
  rm ../scripts/master/certs ../scripts/master/configs ../scripts/worker/certs ../scripts/worker/configs -rf
  rm ../scripts/master/*secret* ../scripts/worker/*secret* -rf

  echo "Deleting terraform state"
  rm terraform.tfstate* -rf
fi