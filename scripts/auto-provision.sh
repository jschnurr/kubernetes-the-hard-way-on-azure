#!/bin/bash
# $1 log output file w/ path and extension

terraform init

if [ ! -z "$1" ]
then 
  terraform apply -auto-approve -var-file azurerm-secret.tfvars 2>&1 | tee $1
else
  terraform apply -auto-approve -var-file azurerm-secret.tfvars
fi