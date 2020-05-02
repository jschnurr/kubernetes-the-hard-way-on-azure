#!/bin/bash
# $1 do certificates, configurations & terraform state cleanup?

if [ ! -z "$1" ] && ( $1 )
then
  echo "Deleting certs and configs"
  rm ../scripts/master/certs master/configs worker/certs worker/configs -rf
  rm ../scripts/master/*secret* worker/*secret* -rf
fi

if [ -s terraform.tfstate ]
then
  echo "Terraform destroy"
  terraform destroy -var-file=azurerm-secret.tfvars -auto-approve
fi

if [ ! -z "$1" ] && ( $1 )
then
  echo "Deleting terraform state"
  rm terraform.tfstate* -rf
fi