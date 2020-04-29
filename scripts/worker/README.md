# Install kubernetes in worker node

## Create certificates
```
# comment line starting with RANDFILE in /etc/ssl/openssl.cnf definition to avoid permission issues
sudo sed -i '0,/RANDFILE/{s/^RANDFILE/\#&/}' /etc/ssl/openssl.cnf

# modify user permissions to read, write and execute all shell scripts
cd ~/kthw-azure-git/scripts
chmod +x *.sh

# create a directory to hold all the generated certificates
cd ~/kthw-azure-git/scripts/worker
mkdir certs

# copy ca certs from master
cd ~/kthw-azure-git/scripts/worker
cp ../master/certs/ca* certs/

# create a directory to hold all the generated configurations
cd ~/kthw-azure-git/scripts/worker
mkdir configs

# copy admin kubeconfig file
cd ~/kthw-azure-git/scripts/worker
cp ../master/configs/admin.kubeconfig configs/
```

### Create kube-proxy certificate
```
cd ~/kthw-azure-git/scripts/worker

.././gen-simple-cert.sh kube-proxy ca "/CN=system:kube-proxy"

# verify generated certificate
openssl x509 -text -in certs/kube-proxy.crt
```

### Create bootstrap token for kubelet
```
cd ~/kthw-azure-git/scripts/worker

# copy the template bootstrap token yaml file
cp bootstrap-token.yaml configs/bootstrap-token.yaml

# substitute the value for <TOKEN_ID> with random 6 character alphanumeric string (0-9a-z)
sed -i "s|<TOKEN_ID>|$(date +%N%s | sha256sum | head -c 6)|g" configs/bootstrap-token.yaml

# substitute the value for <TOKEN_SECRET> with random 16 character alphanumeric string (0-9a-z)
sed -i "s|<TOKEN_SECRET>|$(date +%N%s | sha256sum | head -c 16)|g" configs/bootstrap-token.yaml

# verify generated bootstrap token yaml file
cat configs/bootstrap-token.yaml

# create bootstrap token secret
kubectl apply -f configs/bootstrap-token.yaml --kubeconfig configs/admin.kubeconfig

```

### Create cluster role binding for kubelet to auto create csr
```
cd ~/kthw-azure-git/scripts/worker

kubectl create -f csr-for-bootstrapping.yaml --kubeconfig configs/admin.kubeconfig
```

### Create cluster role binding for kubelet to auto approve csr
```
cd ~/kthw-azure-git/scripts/worker

kubectl create -f auto-approve-csrs-for-group.yaml --kubeconfig configs/admin.kubeconfig
```

### Create cluster role binding for kubelet to auto renew certificates on expiration
```
cd ~/kthw-azure-git/scripts/worker

kubectl create -f auto-approve-renewals-for-nodes.yaml --kubeconfig configs/admin.kubeconfig
```


## Create kubernetes configurations

### Create kube-proxy kube config file
```
cd ~/kthw-azure-git/scripts/worker

# generate the kube config file for kube-proxy service
.././gen-kube-config.sh kubernetes-the-hard-way-azure \
  certs/ca \
  https://<PREFIX>-<ENVIRONMENT>-apiserver.<LOCATION_CODE>.cloudapp.azure.com:6443 \
  configs/kube-proxy \
  system:kube-proxy \
  certs/kube-proxy

# substitute the value for <PREFIX>, <ENVIRONMENT> and <LOCATION_CODE> as done in the previous sections for e.g., the command for generating for 'kthw' prefix, 'play' environment and 'australiaeast' as location code looks like this:
.././gen-kube-config.sh kubernetes-the-hard-way-azure \
  certs/ca \
  https://kthw-play-apiserver.australiaeast.cloudapp.azure.com:6443 \
  configs/kube-proxy \
  system:kube-proxy \
  certs/kube-proxy
```

### Create bootstrap kube config file for kubelet
```
cd ~/kthw-azure-git/scripts/worker

# generate the kube config file for kubelet service
.././gen-bootstrap-kube-config.sh bootstrap \
  certs/ca \
  https://<PREFIX>-<ENVIRONMENT>-apiserver.<LOCATION_CODE>.cloudapp.azure.com:6443 \
  configs/bootstrap-kubeconfig \
  kubelet-bootstrap \
  $(cat configs/bootstrap-token.yaml | grep -oP "token-id:\s?\K\w+").$(cat configs/bootstrap-token.yaml | grep -oP "token-secret:\s?\K\w+")

# substitute the value for <PREFIX>, <ENVIRONMENT> and <LOCATION_CODE> as done in the previous sections for e.g., the command for generating for 'kthw' prefix, 'play' environment and 'australiaeast' as location code looks like this:
.././gen-bootstrap-kube-config.sh bootstrap \
  certs/ca \
  https://kthw-play-apiserver.australiaeast.cloudapp.azure.com:6443 \
  configs/bootstrap-kubeconfig \
  kubelet-bootstrap \
  $(cat configs/bootstrap-token.yaml | grep -oP "token-id:\s?\K\w+").$(cat configs/bootstrap-token.yaml | grep -oP "token-secret:\s?\K\w+")
```


## Install worker node pre-requisites

### Remote login to workervm01
```
ssh usr1@<PREFIX>-<ENVIRONMENT>-workervm01.<LOCATION_CODE>.cloudapp.azure.com

# substitute the value for <PREFIX>, <ENVIRONMENT> and <LOCATION_CODE> as done in the previous sections for e.g., the command for generating for 'kthw' prefix, 'play' environment and 'australiaeast' as location code looks like this:
ssh usr1@kthw-play-workervm01.australiaeast.cloudapp.azure.com
```

### Install socat binary to enable 'kubectl port-forward' command (inside worker node)
```
{
  sudo apt-get update
  sudo apt-get -y install socat conntrack ipset
}
```

### Disable swap (inside worker node)
```
# verify if swap is enabled
sudo swapon --show

# if output is not empty then disable swap
sudo swapoff -a

# remote logout from workervm01
logout
```

### Download, install and configure cni networking (inside worker node)
```
cd ~/kthw-azure-git/scripts/worker

# remote copy to the workervm01
scp 10-bridge.conf 99-loopback.conf \
  usr1@<PREFIX>-<ENVIRONMENT>-workervm01.<LOCATION_CODE>.cloudapp.azure.com:~

# substitute the value for <PREFIX>, <ENVIRONMENT> and <LOCATION_CODE> as done in the previous sections for e.g., the command for generating for 'kthw' prefix, 'play' environment and 'australiaeast' as location code looks like this:
scp 10-bridge.conf 99-loopback.conf \
  usr1@kthw-play-workervm01.australiaeast.cloudapp.azure.com:~

# remote login to workervm01
ssh usr1@<PREFIX>-<ENVIRONMENT>-workervm01.<LOCATION_CODE>.cloudapp.azure.com

# substitute the value for <PREFIX>, <ENVIRONMENT> and <LOCATION_CODE> as done in the previous sections for e.g., the command for generating for 'kthw' prefix, 'play' environment and 'australiaeast' as location code looks like this:
ssh usr1@kthw-play-workervm01.australiaeast.cloudapp.azure.com

cd ~

# download cni plugin v0.8.5
wget -q --show-progress --https-only --timestamping \
  "https://github.com/containernetworking/plugins/releases/download/v0.8.5/cni-plugins-linux-amd64-v0.8.5.tgz"

# configure cni plugin
{
  sudo mkdir -p \
    /etc/cni/net.d \
    /opt/cni/bin
  sudo tar -xvf cni-plugins-linux-amd64-v0.8.5.tgz -C /opt/cni/bin/
  rm cni-plugins-linux-amd64-v0.8.5.tgz
}

# prepare cni configuration files

# substitute the value for <POD_CIDR>
# e.g. 10.200.1.0/24 for workervm01, 10.200.2.0/24 for workervm02 etc.
sed -i 's|<POD_CIDR>|10.200.1.0\/24|g' 10-bridge.conf

# verify cni configuration file
cat 10-bridge.conf

# move cni configuration files
sudo mv 10-bridge.conf 99-loopback.conf /etc/cni/net.d/

# remote logout from workervm01
logout
```

### Download, install and configure containerd container runtime (inside worker node)
```
cd ~/kthw-azure-git/scripts/worker

# remote copy to the workervm01
scp config.toml containerd.service \
  usr1@<PREFIX>-<ENVIRONMENT>-workervm01.<LOCATION_CODE>.cloudapp.azure.com:~

# substitute the value for <PREFIX>, <ENVIRONMENT> and <LOCATION_CODE> as done in the previous sections for e.g., the command for generating for 'kthw' prefix, 'play' environment and 'australiaeast' as location code looks like this:
scp config.toml containerd.service \
  usr1@kthw-play-workervm01.australiaeast.cloudapp.azure.com:~

# remote login to workervm01
ssh usr1@<PREFIX>-<ENVIRONMENT>-workervm01.<LOCATION_CODE>.cloudapp.azure.com

# substitute the value for <PREFIX>, <ENVIRONMENT> and <LOCATION_CODE> as done in the previous sections for e.g., the command for generating for 'kthw' prefix, 'play' environment and 'australiaeast' as location code looks like this:
ssh usr1@kthw-play-workervm01.australiaeast.cloudapp.azure.com

cd ~

# download containerd v1.2.13
wget -q --show-progress --https-only --timestamping \
  "https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.18.0/crictl-v1.18.0-linux-amd64.tar.gz" \
  "https://github.com/opencontainers/runc/releases/download/v1.0.0-rc10/runc.amd64" \
  "https://github.com/containerd/containerd/releases/download/v1.2.13/containerd-1.2.13.linux-amd64.tar.gz"

# configure containerd
{
  sudo mkdir -p /etc/containerd/

  mkdir containerd
  tar -xvf containerd-1.2.13.linux-amd64.tar.gz -C containerd
  sudo mv containerd/bin/* /bin/

  tar -xvf crictl-v1.18.0-linux-amd64.tar.gz
  sudo mv runc.amd64 runc
  chmod +x crictl runc
  sudo mv crictl runc /usr/local/bin/

  rm containerd/ -r
  rm crictl-v1.18.0-linux-amd64.tar.gz containerd-1.2.13.linux-amd64.tar.gz
}

# move containerd config file
sudo mv config.toml /etc/containerd/config.toml

# move containerd systemd unit file
sudo mv containerd.service /etc/systemd/system/containerd.service
```

### Start containerd service (inside worker node)
```
{
  sudo systemctl daemon-reload
  sudo systemctl enable containerd
  sudo systemctl start containerd
}
```

### Verify containerd service (inside worker node)
```
systemctl status containerd
journalctl -e -u containerd

# remote logout from workervm01
logout
```


## Install kubernetes kubelet

### Remote copy files to worker node
```
cd ~/kthw-azure-git/scripts/worker

# remote copy to the workervm01
scp certs/ca.crt configs/bootstrap-kubeconfig kubelet-config.yaml kubelet.service \
  usr1@<PREFIX>-<ENVIRONMENT>-workervm01.<LOCATION_CODE>.cloudapp.azure.com:~

# substitute the value for <PREFIX>, <ENVIRONMENT> and <LOCATION_CODE> as done in the previous sections for e.g., the command for generating for 'kthw' prefix, 'play' environment and 'australiaeast' as location code looks like this:
scp certs/ca.crt configs/bootstrap-kubeconfig kubelet-config.yaml kubelet.service \
  usr1@kthw-play-workervm01.australiaeast.cloudapp.azure.com:~
```

### Download, install and configure kubelet service (inside worker node)
```
# remote login to workervm01
ssh usr1@<PREFIX>-<ENVIRONMENT>-workervm01.<LOCATION_CODE>.cloudapp.azure.com

# substitute the value for <PREFIX>, <ENVIRONMENT> and <LOCATION_CODE> as done in the previous sections for e.g., the command for generating for 'kthw' prefix, 'play' environment and 'australiaeast' as location code looks like this:
ssh usr1@kthw-play-workervm01.australiaeast.cloudapp.azure.com

cd ~

# download kubelet v1.18.1
wget -q --show-progress --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.18.1/bin/linux/amd64/kubelet"

# configure kubelet service
{
  sudo mkdir -p /var/lib/kubelet /var/lib/kubernetes
  chmod +x kubelet
  sudo mv kubelet /usr/local/bin/
  sudo mv bootstrap-kubeconfig /var/lib/kubelet/
  sudo mv ca.crt /var/lib/kubernetes/
}

# prepare kubelet config file

# substitute the value for <POD_CIDR>
# e.g. 10.200.1.0/24 for workervm01, 10.200.2.0/24 for workervm02 etc.
sed -i 's|<POD_CIDR>|10.200.1.0\/24|g' kubelet-config.yaml

# verify kubelet config file
cat kubelet-config.yaml

# move kubelet config file
sudo mv kubelet-config.yaml /var/lib/kubelet/kubelet-config.yaml

# move kubelet systemd unit file
sudo mv kubelet.service /etc/systemd/system/kubelet.service
```

### Start kubelet service (inside worker node)
```
{
  sudo systemctl daemon-reload
  sudo systemctl enable kubelet
  sudo systemctl start kubelet
}
```

### Verify kubelet service (inside worker node)
```
systemctl status kubelet
journalctl -e -u kubelet

# remote logout from workervm01
logout
```

### Approve certificate signing request (csr) of worker node
```
cd ~/kthw-azure-git/scripts/worker

# get the csr name
kubectl get csr --kubeconfig configs/admin.kubeconfig

# approve the csr by substituting the value under 'Name' as <CSR_NAME> from the output of previous command having condition as Pending
kubectl certificate approve <CSR_NAME> --kubeconfig configs/admin.kubeconfig
```


## Install kubernetes kube-proxy

### Remote copy files to worker node
```
cd ~/kthw-azure-git/scripts/worker

# remote copy to the workervm01
scp configs/kube-proxy.kubeconfig kube-proxy-config.yaml kube-proxy.service \
  usr1@<PREFIX>-<ENVIRONMENT>-workervm01.<LOCATION_CODE>.cloudapp.azure.com:~

# substitute the value for <PREFIX>, <ENVIRONMENT> and <LOCATION_CODE> as done in the previous sections for e.g., the command for generating for 'kthw' prefix, 'play' environment and 'australiaeast' as location code looks like this:
scp configs/kube-proxy.kubeconfig kube-proxy-config.yaml kube-proxy.service \
  usr1@kthw-play-workervm01.australiaeast.cloudapp.azure.com:~
```

### Download, install and configure kube-proxy service (inside worker node)
```
# remote login to workervm01
ssh usr1@<PREFIX>-<ENVIRONMENT>-workervm01.<LOCATION_CODE>.cloudapp.azure.com

# substitute the value for <PREFIX>, <ENVIRONMENT> and <LOCATION_CODE> as done in the previous sections for e.g., the command for generating for 'kthw' prefix, 'play' environment and 'australiaeast' as location code looks like this:
ssh usr1@kthw-play-workervm01.australiaeast.cloudapp.azure.com

cd ~

# download kube-proxy v1.18.1
wget -q --show-progress --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.18.1/bin/linux/amd64/kube-proxy"

# configure kube-proxy service
{
  sudo mkdir -p /var/lib/kube-proxy
  chmod +x kube-proxy
  sudo mv kube-proxy /usr/local/bin/
  sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
}

# prepare kube-proxy config file

# substitute the value for <CLUSTER_CIDR>
sed -i 's|<CLUSTER_CIDR>|10.200.0.0\/16|g' kube-proxy-config.yaml

# verify kube-proxy config file
cat kube-proxy-config.yaml

# move kube-proxy config file
sudo mv kube-proxy-config.yaml /var/lib/kube-proxy/kube-proxy-config.yaml

# move kube-proxy systemd unit file
sudo mv kube-proxy.service /etc/systemd/system/kube-proxy.service
```

### Start kube-proxy service (inside worker node)
```
{
  sudo systemctl daemon-reload
  sudo systemctl enable kube-proxy
  sudo systemctl start kube-proxy
}
```

### Verify kube-proxy service (inside worker node)
```
systemctl status kube-proxy
journalctl -e -u kube-proxy

# remote logout from workervm01
logout
```


## Verification of worker node setup after everything
```
cd ~/kthw-azure-git/scripts/worker

kubectl get nodes --kubeconfig configs/admin.kubeconfig

# output should be something like this
NAME                   STATUS   ROLES    AGE   VERSION
kthw-play-workervm01   Ready    <none>   10m   v1.18.1
```