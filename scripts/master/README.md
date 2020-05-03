# Install kubernetes in master node

## Initialisation
```
cd ~/kthw-azure-git/infra

# load variables already set for the infrastructure
source azurerm-secret.tfvars

# determine location code from location
location_code=$(az account list-locations --query "[?displayName=='$location']".{Code:name} -o tsv)

# modify user permissions to execute all shell scripts
cd ~/kthw-azure-git/scripts
chmod +x *.sh
```

## Create certificates
```
# create a directory to hold all the generated certificates
cd ~/kthw-azure-git/scripts/master
mkdir certs
```

### Create ca certificate
```
cd ~/kthw-azure-git/scripts/master

../gen-ca-cert.sh ca "/CN=KUBERNETES-CA"

# verify generated certificate
openssl x509 -text -in certs/ca.crt
```

### Create admin client certificate
```
cd ~/kthw-azure-git/scripts/master

../gen-simple-cert.sh admin ca "/CN=admin/O=system:masters"

# verify generated certificate
openssl x509 -text -in certs/admin.crt
```

### Create kube-scheduler client certificate
```
cd ~/kthw-azure-git/scripts/master

../gen-simple-cert.sh kube-scheduler ca "/CN=system:kube-scheduler"

# verify generated certificate
openssl x509 -text -in certs/kube-scheduler.crt
```

### Create kube-controller-manager client certificate
```
cd ~/kthw-azure-git/scripts/master

../gen-simple-cert.sh kube-controller-manager ca "/CN=system:kube-controller-manager"

# verify generated certificate
openssl x509 -text -in certs/kube-controller-manager.crt
```

### Create service account key pair certificate
```
cd ~/kthw-azure-git/scripts/master

../gen-simple-cert.sh service-account ca "/CN=service-accounts"

# verify generated certificate
openssl x509 -text -in certs/service-account.crt
```

### Create etcd server certificate
```
cd ~/kthw-azure-git/scripts/master

../gen-advanced-cert.sh etcd-server ca "/CN=etcd-server" openssl-etcd

# verify generated certificate
openssl x509 -text -in certs/etcd-server.crt
```

### Create kube-apiserver certificate
```
cd ~/kthw-azure-git/scripts/master

# copy the template openssl config file
cp openssl-kube-apiserver.cnf openssl-kube-apiserver-secret.cnf

# generate openssl configuration file for your environment
sed -i "s|<PREFIX>|$prefix|g; s|<ENVIRONMENT>|$environment|g; s|<LOCATION_CODE>|$location_code|g" openssl-kube-apiserver-secret.cnf

# generate certificate passing the openssl configuration generated from last step
../gen-advanced-cert.sh kube-apiserver ca "/CN=kube-apiserver" openssl-kube-apiserver-secret

# verify generated certificate
openssl x509 -text -in certs/kube-apiserver.crt
```


## Create kubernetes configurations
```
# create a directory to hold all the generated configurations
cd ~/kthw-azure-git/scripts/master
mkdir configs
```

### Create admin kube config file
```
cd ~/kthw-azure-git/scripts/master

# generate the kube config file for admin user
../gen-kube-config.sh kubernetes-the-hard-way-azure \
  certs/ca \
  "https://$prefix-$environment-apiserver.$location_code.cloudapp.azure.com:6443" \
  configs/admin \
  admin \
  certs/admin
```

### Create kube-scheduler kube config file
```
cd ~/kthw-azure-git/scripts/master

# generate the kube config file for kube-scheduler service
../gen-kube-config.sh kubernetes-the-hard-way-azure \
  certs/ca \
  "https://$prefix-$environment-apiserver.$location_code.cloudapp.azure.com:6443" \
  configs/kube-scheduler \
  system:kube-scheduler \
  certs/kube-scheduler
```

### Create kube-controller-manager kube config file
```
cd ~/kthw-azure-git/scripts/master

# generate the kube config file for kube-controller-manager service
../gen-kube-config.sh kubernetes-the-hard-way-azure \
  certs/ca \
  "https://$prefix-$environment-apiserver.$location_code.cloudapp.azure.com:6443" \
  configs/kube-controller-manager \
  system:kube-controller-manager \
  certs/kube-controller-manager
```


## Install etcd server

### Remote copy files to master node
```
cd ~/kthw-azure-git/scripts/master

# remote copy to mastervm01
scp certs/ca.crt certs/etcd* etcd.service \
  usr1@$prefix-$environment-mastervm01.$location_code.cloudapp.azure.com:~
```

### Download, install and configure etcd server (inside master node)
```
# remote login to mastervm01
ssh usr1@$prefix-$environment-mastervm01.$location_code.cloudapp.azure.com

cd ~

# download etcd v3.4.7 
wget -q --show-progress --https-only --timestamping \
  "https://github.com/etcd-io/etcd/releases/download/v3.4.7/etcd-v3.4.7-linux-amd64.tar.gz"

# extract etcd binaries and install
{
  tar -xvf etcd-v3.4.7-linux-amd64.tar.gz
  sudo mv etcd-v3.4.7-linux-amd64/etcd* /usr/local/bin/
  rm etcd-v3.4.7-linux-amd64.tar.gz
  rm etcd-v3.4.7-linux-amd64 -r
}

# configure etcd server
{
  sudo mkdir -p /etc/etcd /var/lib/etcd
  sudo mv ca.crt etcd-server.crt etcd-server.key /etc/etcd/
}

# prepare etcd service systemd unit file

# substitute the value for <HOSTNAME>
# e.g. "kthw-play-mastervm01" for mastervm01 with 'kthw' as prefix and 'play' as environmemt
sed -i "s|<HOSTNAME>|$(hostname -s)|g" etcd.service

# substitute the value for <INTERNAL_IP>
# e.g. "10.240.0.11" for mastervm01, "10.240.0.12" for mastervm02 etc.
sed -i "s|<INTERNAL_IP>|$(hostname -i)|g" etcd.service

# verify etcd service systemd unit file
cat etcd.service

# move etcd service systemd unit file
sudo mv etcd.service /etc/systemd/system/etcd.service
```

### Start etcd server (inside master node)
```
{
  sudo systemctl daemon-reload
  sudo systemctl enable etcd
  sudo systemctl start etcd
}
```

### Verify etcd server (inside master node)
```
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.crt \
  --cert=/etc/etcd/etcd-server.crt \
  --key=/etc/etcd/etcd-server.key

# output should be something like this
ffed16798470cab5, started, kthw-play-mastervm01, https://10.240.0.11:2380, https://10.240.0.11:2379, false

# if not then check the service status
systemctl status etcd
journalctl -e -u etcd

# remote logout from mastervm01
logout
```


## Install kubernetes api server

### Create encryption key
```
cd ~/kthw-azure-git/scripts/master

# copy the template encryption config yaml file
cp encryption-config.yaml configs/encryption-config.yaml

# generate openssl encryption config yaml file by substituting encyrption key with random value
sed -i "s|<ENCRYPTION_KEY>|$(date +%N%s | sha256sum | head -c 32 | base64)|g" configs/encryption-config.yaml
```

### Remote copy files to master node
```
cd ~/kthw-azure-git/scripts/master

# remote copy to the mastervm01
scp certs/ca.crt certs/ca.key certs/kube-apiserver* certs/service-account* certs/etcd* \
  configs/encryption-config.yaml kube-apiserver.service \
  usr1@$prefix-$environment-mastervm01.$location_code.cloudapp.azure.com:~
```

### Download, install and configure kube-apiserver service (inside master node)
```
# remote login to mastervm01
ssh usr1@$prefix-$environment-mastervm01.$location_code.cloudapp.azure.com

cd ~

# download kube-apiserver v1.18.1
wget -q --show-progress --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.18.1/bin/linux/amd64/kube-apiserver"

# configure kube-apiserver service
{
  chmod +x kube-apiserver
  sudo mv kube-apiserver /usr/local/bin/
  sudo mkdir -p /var/lib/kubernetes/
  sudo mv ca.crt ca.key kube-apiserver.crt kube-apiserver.key \
    service-account.crt service-account.key \
    etcd-server.crt etcd-server.key \
    encryption-config.yaml /var/lib/kubernetes/
}

# prepare kube-apiserver service systemd unit file

# substitute the value for <INTERNAL_IP>
# e.g. "10.240.0.11" for mastervm01, "10.240.0.12" for mastervm02 etc.
sed -i "s|<INTERNAL_IP>|$(hostname -i)|g" kube-apiserver.service

# verify kube-apiserver service systemd unit file
cat kube-apiserver.service

# move kube-apiserver service systemd unit file
sudo mv kube-apiserver.service /etc/systemd/system/kube-apiserver.service
```

### Start kube-apiserver service (inside master node)
```
{
  sudo systemctl daemon-reload
  sudo systemctl enable kube-apiserver
  sudo systemctl start kube-apiserver
}
```

### Verify kube-apiserver service (inside master node)
```
systemctl status kube-apiserver
journalctl -e -u kube-apiserver

# remote logout from mastervm01
logout
```

### Add kube-apiserver user to system:kube-apiserver-to-kubelet role (new) for exec and port-forward operation access
```
cd ~/kthw-azure-git/scripts/master

kubectl apply -f kube-apiserver-to-kubelet.yaml --kubeconfig configs/admin.kubeconfig
```


## Install kubernetes scheduler

### Remote copy files to master node
```
cd ~/kthw-azure-git/scripts/master

# remote copy to the mastervm01
scp configs/kube-scheduler.kubeconfig kube-scheduler.service \
  usr1@$prefix-$environment-mastervm01.$location_code.cloudapp.azure.com:~
```

### Download, install and configure kube-scheduler service (inside master node)
```
# remote login to mastervm01
ssh usr1@$prefix-$environment-mastervm01.$location_code.cloudapp.azure.com

cd ~

# download kube-scheduler v1.18.1
wget -q --show-progress --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.18.1/bin/linux/amd64/kube-scheduler"

# configure kube-scheduler service
{
  chmod +x kube-scheduler
  sudo mv kube-scheduler /usr/local/bin/
  sudo mv kube-scheduler.kubeconfig /var/lib/kubernetes/
}

# move kube-scheduler service systemd unit file
sudo mv kube-scheduler.service /etc/systemd/system/kube-scheduler.service
```

### Start kube-scheduler service (inside master node)
```
{
  sudo systemctl daemon-reload
  sudo systemctl enable kube-scheduler
  sudo systemctl start kube-scheduler
}
```

### Verify kube-scheduler service (inside master node)
```
systemctl status kube-scheduler
journalctl -e -u kube-scheduler

# remote logout from mastervm01
logout
```


## Install kubernetes controller manager

### Remote copy files to master node
```
cd ~/kthw-azure-git/scripts/master

# remote copy to the mastervm01
scp configs/kube-controller-manager.kubeconfig kube-controller-manager.service \
  usr1@$prefix-$environment-mastervm01.$location_code.cloudapp.azure.com:~
```

### Download, install and configure kube-controller-manager service (inside master node)
```
# remote login to mastervm01
ssh usr1@$prefix-$environment-mastervm01.$location_code.cloudapp.azure.com

cd ~

# download kube-controller-manager v1.18.1
wget -q --show-progress --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.18.1/bin/linux/amd64/kube-controller-manager"

# configure kube-controller-manager service
{
  chmod +x kube-controller-manager
  sudo mv kube-controller-manager /usr/local/bin/
  sudo mv kube-controller-manager.kubeconfig /var/lib/kubernetes/
}

# move kube-controller-manager service systemd unit file
sudo mv kube-controller-manager.service /etc/systemd/system/kube-controller-manager.service
```

### Start kube-controller-manager service (inside master node)
```
{
  sudo systemctl daemon-reload
  sudo systemctl enable kube-controller-manager
  sudo systemctl start kube-controller-manager
}
```

### Verify kube-controller-manager service (inside master node)
```
systemctl status kube-controller-manager
journalctl -e -u kube-controller-manager

# remote logout from mastervm01
logout
```


## Enable http health checks

### Remote copy files to master node
```
cd ~/kthw-azure-git/scripts/master

# remote copy to the mastervm01
scp healthprobe \
  usr1@$prefix-$environment-mastervm01.$location_code.cloudapp.azure.com:~
```

### Download, install and configure nginx (inside master node)
```
# remote login to mastervm01
ssh usr1@$prefix-$environment-mastervm01.$location_code.cloudapp.azure.com

cd ~

# download nginx latest version
{
  sudo apt-get update
  sudo apt-get install -y nginx
}

# configure nginx service
{
  sudo mv healthprobe \
    /etc/nginx/sites-available/healthprobe

  sudo ln -s /etc/nginx/sites-available/healthprobe /etc/nginx/sites-enabled/
}
```

### Start nginx service (inside master node)
```
{
  sudo systemctl enable nginx
  sudo systemctl restart nginx
}
```

### Verify http health checks (inside master node)
```
curl -H "Host: kubernetes.default.svc.cluster.local" -i http://127.0.0.1/healthz

# output should be something like this
HTTP/1.1 200 OK
Server: nginx/1.14.0 (Ubuntu)
Date: Tue, 28 Apr 2020 04:02:15 GMT
Content-Type: text/plain; charset=utf-8
Content-Length: 2
Connection: keep-alive
X-Content-Type-Options: nosniff

# if not then check the service status
systemctl status nginx
journalctl -e -u nginx

# remote logout from mastervm01
logout
```

### Verify master node setup before azure network load balancer health probe is enabled
```
cd ~/kthw-azure-git/scripts/master

kubectl get componentstatuses --kubeconfig configs/admin.kubeconfig

# output should be something like this
NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-0               Healthy   {"health":"true"}
```

### Enable azure network load balancer health probe
```
cd ~/kthw-azure-git/infra

# set the variable - 'enable_health_probe' value as true
sed -i 's|^enable_health_probe.*$|enable_health_probe=true|g' azurerm-secret.tfvars

terraform apply -var-file=azurerm-secret.tfvars
```


## Verification of master node setup after everything
```
cd ~/kthw-azure-git/scripts/master

kubectl get componentstatuses --kubeconfig configs/admin.kubeconfig

# output should be something like this
NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-0               Healthy   {"health":"true"}
```