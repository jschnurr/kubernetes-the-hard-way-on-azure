# Install coredns

## Deploy definition file
```
cd ~/kthw-azure-git/scripts

kubectl apply -f deployments/coredns.yaml --kubeconfig worker/configs/admin.kubeconfig
```

## Verification of kubernetes setup after completion of all actions
```
cd ~/kthw-azure-git/scripts

kubectl get componentstatuses --kubeconfig configs/admin.kubeconfig

# output should be something like this
NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-0               Healthy   {"health":"true"}
```