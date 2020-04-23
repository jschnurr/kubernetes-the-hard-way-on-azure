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

# copy the template openssl config
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