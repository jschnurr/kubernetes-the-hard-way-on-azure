# Install kubernetes in master node

## Create and install certificates
```
# comment line starting with RANDFILE in /etc/ssl/openssl.cnf definition to avoid permission issues
sudo sed -i '0,/RANDFILE/{s/^RANDFILE/\#&/}' /etc/ssl/openssl.cnf

# modify user permissions to read, write and execute all shell scripts
cd ~/kthw-azure-git/scripts
chmod u=rwx *.sh

# create a directory to hold all the generated certificates
cd ~/kthw-azure-git/scripts/master
mkdir certs
```

### Create ca certificate
```
cd ~/kthw-azure-git/scripts/master
.././gen-ca-cert.sh ca "/CN=KUBERNETES-CA"

# verify the generated cert
openssl x509 -text -in certs/ca.crt
```

### Create admin client certificate
```
cd ~/kthw-azure-git/scripts/master
.././gen-simple-cert.sh admin ca "/CN=admin/O=system:masters"

# verify the generated cert
openssl x509 -text -in certs/admin.crt
```

### Create kube-scheduler client certificate
```
cd ~/kthw-azure-git/scripts/master
.././gen-simple-cert.sh kube-scheduler ca "/CN=system:kube-scheduler"

# verify the generated cert
openssl x509 -text -in certs/kube-scheduler.crt
```

### Create kube-controller-manager client certificate
```
cd ~/kthw-azure-git/scripts/master
.././gen-simple-cert.sh kube-controller-manager ca "/CN=system:kube-controller-manager"

# verify the generated cert
openssl x509 -text -in certs/kube-controller-manager.crt
```

### Create service account key pair
```
cd ~/kthw-azure-git/scripts/master
.././gen-simple-cert.sh service-account ca "/CN=service-accounts"

# verify the generated cert
openssl x509 -text -in certs/service-account.crt
```

### Create etcd server certificate
```
cd ~/kthw-azure-git/scripts/master
.././gen-advanced-cert.sh etcd-server ca "/CN=etcd-server" openssl-etcd

# verify the generated cert
openssl x509 -text -in certs/etcd-server.crt
```

### Create kube-apiserver certificate
```
cd ~/kthw-azure-git/scripts/master

# copy the template openssl config file
cp openssl-kube-apiserver.cnf openssl-kube-apiserver-secret.cnf

# generate openssl configuration file for your environment by replacing VALUE in the following command:
sed -i 's/<PREFIX>/VALUE/g; s/<ENVIRONMENT>/VALUE/g; s/<LOCATION_CODE>/VALUE/g' openssl-kube-apiserver-secret.cnf

# to know the VALUE for your <LOCATION_CODE>, note the corresponding value under the 'Name' column from the following command output:
az account list-locations -o table

# refer to infra/azurerm-secret.tfvars file for what values you chose for your environment for e.g., the command for generating for 'kthw' prefix, 'play' environment and 'australiaeast' as location code looks like this:
sed -i 's/<PREFIX>/kthw/g; s/<ENVIRONMENT>/play/g; s/<LOCATION_CODE>/australiaeast/g' openssl-kube-apiserver-secret.cnf

# generate the certificate passing the openssl configuration generated from last step
.././gen-advanced-cert.sh kube-apiserver ca "/CN=kube-apiserver" openssl-kube-apiserver-secret

# verify the generated cert
openssl x509 -text -in certs/kube-apiserver.crt
```

## Install etcd server

### Remote copy files to master node
```
cd ~/kthw-azure-git/scripts/master

# remote copy to the mastervm01
scp certs/ca.crt certs/etcd* etcd.service \
    usr1@kthw-play-mastervm01.australiaeast.cloudapp.azure.com:~
```

### Download, install and configure etcd server (inside master node)
```
# remote login to the mastervm01
ssh usr1@kthw-play-mastervm01.australiaeast.cloudapp.azure.com

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

# configure the etcd server
{
  sudo mkdir -p /etc/etcd /var/lib/etcd
  sudo cp ca.crt etcd-server.key etcd-server.crt /etc/etcd/
}

# prepare the etcd service systemd unit file

# substitute the value for <HOSTNAME>
# e.g. "kthw-play-mastervm01" for mastervm01 with 'kthw' as prefix and 'play' as environmemt
sed -i "s|<HOSTNAME>|$(hostname -s)|g" etcd.service

# substitute the value for <INTERNAL_IP> by replacing VALUE in the following command:
# e.g. "10.240.0.11" for mastervm01, "10.240.0.12" for mastervm02 etc.
sed -i "s|<INTERNAL_IP>|$(hostname -i)|g" etcd.service

# verify the etcd service systemd unit file
cat etcd.service

# copy the etcd service systemd unit file
sudo cp etcd.service /etc/systemd/system/etcd.service
```

### Start the etcd server
```
{
  sudo systemctl daemon-reload
  sudo systemctl enable etcd
  sudo systemctl start etcd
}
```

### Verify the etcd server
```
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.crt \
  --cert=/etc/etcd/etcd-server.crt \
  --key=/etc/etcd/etcd-server.key

# output should be something like this
# ffed16798470cab5, started, kthw-play-mastervm01, https://10.240.0.11:2380, https://10.240.0.11:2379, false
```

### Create encryption key
```
cd ~/kthw-azure-git/scripts/master

# copy the template encryption config yaml file
cp encryption-config.yaml encryption-config-secret.yaml

# generate openssl encryption config yaml file by substituting encyrption key with random value
sed -i "s|<ENCRYPTION_KEY>|$(head -c 32 /dev/urandom | base64)|g" encryption-config-secret.yaml

```