#!/bin/bash
# $1 total master nodes
# $2 current master node number to be setup

cd ~

# prepare kube-apiserver service systemd unit file
echo "Started preparation of kube-apiserver service systemd unit file"

# substitute the value for <INTERNAL_IP>
sed -i "s|<INTERNAL_IP>|$(hostname -i)|g" kube-apiserver.service

# replace the etcd servers value in kube-apiserver.service
new_value=""
for (( i=1; i<=$1; i++ ))
do
  new_value+="https://10.240.0.1$i:2379,"
done
new_value=${new_value%,}
old_value=$(grep -oP "^\s+--etcd-servers=\K.*(?=\s+\\\\$)" kube-apiserver.service)
sed -i "s|--etcd-servers=$old_value|--etcd-servers=$new_value|g" kube-apiserver.service
echo "Completed preparation of etcd service systemd unit file"

# if kube-apiserver service is already installed
if systemctl list-unit-files | grep -q "^kube-apiserver.service"
then
  echo "Found kube-apiserver as already installed"
  # remove files copied already from remote
  rm ca.crt ca.key kube-apiserver.crt kube-apiserver.key service-account* etcd* encryption-config.yaml

  # move kube-apiserver service systemd unit file
  sudo mv kube-apiserver.service /etc/systemd/system/kube-apiserver.service

  # restart kube-apiserver
  echo "Started restart of kube-apiserver"
  {
    sudo systemctl daemon-reload
    sudo systemctl restart kube-apiserver
  }
  echo "Completed restart of kube-apiserver"

# else etcd service is not installed
else
  echo "Not found kube-apiserver as installed"

  # download kube-apiserver v1.18.1
  echo "Started installation of kube-apiserver"
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

  # move kube-apiserver service systemd unit file
  sudo mv kube-apiserver.service /etc/systemd/system/kube-apiserver.service

  # start kube-apiserver
  echo "Started start of kube-apiserver"
  {
    sudo systemctl daemon-reload
    sudo systemctl enable kube-apiserver
    sudo systemctl start kube-apiserver
  }
  echo "Completed start of kube-apiserver"
  echo "Completed installation of kube-apiserver"
fi