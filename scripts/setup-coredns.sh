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

# give time for coredns to start
echo "Sleeping to give time for coredns to start"
sleep 30

echo -e "\nExecuting 'kubectl run --image=busybox:1.28 busybox -- nslookup kubernetes' output"
# execute nslookup command in the busybox container to test dns
kubectl run --kubeconfig worker/configs/admin.kubeconfig --image=busybox:1.28 busybox -- nslookup kubernetes

# give time for busybox to start
echo "Sleeping to give time for busybox to start"
sleep 10

echo "Displaying 'kubectl logs busybox' output"
# get the results from test dns
kubectl logs busybox --kubeconfig worker/configs/admin.kubeconfig

echo "Displaying 'kubectl delete pod busybox' output"
# cleanup of busybox pod
kubectl delete pod busybox --kubeconfig worker/configs/admin.kubeconfig