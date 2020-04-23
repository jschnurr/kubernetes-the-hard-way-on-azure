# Install kubernetes in master node

## Create and install certificates
```
# comment line starting with RANDFILE in /etc/ssl/openssl.cnf definition to avoid permission issues
sudo sed -i '0,/RANDFILE/{s/^RANDFILE/\#&/}' /etc/ssl/openssl.cnf

# modify user permissions to read, write and execute all shell scripts
cd ~/kthw-azure-git/scripts
chmod u=rwx *.sh

# create a directory to hold all the generated certificates
cd ~/kthw-azure-git/scripts/worker
mkdir certs
```

### Create kubelet client certificate

### Create kube-proxy certificate
