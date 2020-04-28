#!/bin/bash
# $1 = cluster name
# $2 = ca certificate file name w/o extension
# $3 = api server url
# $4 = kube config file name w/o extension
# $5 = user name
# $6 = bootstrap token

{
  kubectl config set-cluster $1 \
    --certificate-authority=$2.crt \
    --embed-certs=true \
    --server=$3 \
    --kubeconfig=$4.kubeconfig

  kubectl config set-credentials $5 \
    --token=$6 \
    --kubeconfig=$4.kubeconfig

  kubectl config set-context default \
    --cluster=$1 \
    --user=$5 \
    --kubeconfig=$4.kubeconfig

  kubectl config use-context default --kubeconfig=$4.kubeconfig
}