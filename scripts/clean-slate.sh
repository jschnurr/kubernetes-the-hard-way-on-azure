#!/bin/bash
# $1 enable certificates, configurations & terraform state cleanup

if [ ! -z "$1" ] && ( $1 )
then
  echo "Deleting certs and configs"
  rm ../scripts/master/certs ../scripts/master/configs ../scripts/worker/certs ../scripts/worker/configs -rf
  rm ../scripts/master/*secret* ../scripts/worker/*secret* -rf
fi

if [ -s terraform.tfstate ]
then
  echo "Terraform destroy"
  terraform destroy -auto-approve -var-file=azurerm-secret.tfvars
fi

if [ ! -z "$1" ] && ( $1 )
then
  echo "Deleting terraform state"
  rm terraform.tfstate* -rf
fi