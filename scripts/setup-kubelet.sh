#!/bin/bash
# remotely executed script
# $1 - current worker node number to be setup

cd ~

# if kubelet service is already installed
if systemctl list-unit-files | grep -q "^kubelet.service"
then
  echo "Found kubelet as already installed"
  # remove files copied already from remote
  rm ca.crt bootstrap-kubeconfig kubelet-config.yaml

  # move kubelet systemd unit file
  sudo mv kubelet.service /etc/systemd/system/kubelet.service

  # restart kubelet
  echo "Started restart of kubelet"
  {
    sudo systemctl daemon-reload
    sudo systemctl restart kubelet
  }
  echo "Completed restart of kubelet"

# else kubelet service is not installed
else
  echo "Not found kubelet as installed"

  # download kubelet v1.18.1
  echo "Started installation of kubelet"
  wget --progress=bar:force:noscroll --https-only \
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
  sed -i "s|<POD_CIDR>|10.200.$1.0\/24|g" kubelet-config.yaml

  # move kubelet config file
  sudo mv kubelet-config.yaml /var/lib/kubelet/kubelet-config.yaml

  # move kubelet systemd unit file
  sudo mv kubelet.service /etc/systemd/system/kubelet.service

  # start kubelet
  echo "Started start of kubelet"
  {
    sudo systemctl daemon-reload
    sudo systemctl enable kubelet
    sudo systemctl start kubelet
  }
  echo "Completed start of kubelet"
  echo "Completed installation of kubelet"
fi