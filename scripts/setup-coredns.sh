#!/bin/bash

echo -e "\nStarted initialisation"
# change current directory from infra
cd ../scripts
echo "Completed initialisation"

echo -e "\nStarted setting up of coredns"
# create coredns deployment
kubectl apply -f deployments/coredns.yaml --kubeconfig worker/configs/admin.kubeconfig

# verify coredns setup after everything
echo -e "\nDisplaying 'kubectl get all --all-namespaces' output"
kubectl get all --all-namespaces --kubeconfig worker/configs/admin.kubeconfig

echo -e "\nDisplaying 'nslookup kubernetes' output"
# execute nslookup command in the dnsutils container to test dns
kubectl run -it --rm --kubeconfig worker/configs/admin.kubeconfig --image=tutum/dnsutils dnsutils -- nslookup kubernetes