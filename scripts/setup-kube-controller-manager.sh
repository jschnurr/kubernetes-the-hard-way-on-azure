#!/bin/bash

cd ~

# if kube-controller-manager service is already installed
if systemctl list-unit-files | grep -q "^kube-controller-manager.service"
then
  echo "Found kube-controller-manager as already installed"
  # remove files copied already from remote
  rm kube-controller-manager.kubeconfig

  # move kube-controller-manager service systemd unit file
  sudo mv kube-controller-manager.service /etc/systemd/system/kube-controller-manager.service

  # restart kube-controller-manager
  echo "Started restart of kube-controller-manager"
  {
    sudo systemctl daemon-reload
    sudo systemctl restart kube-controller-manager
  }
  echo "Completed restart of kube-controller-manager"

# else kube-controller-manager service is not installed
else
  echo "Not found kube-controller-manager as installed"

  # download kube-controller-manager v1.18.1
  echo "Started installation of kube-controller-manager"
  wget --progress=bar:force:noscroll --https-only \
    "https://storage.googleapis.com/kubernetes-release/release/v1.18.1/bin/linux/amd64/kube-controller-manager"

  # configure kube-controller-manager service
  {
    chmod +x kube-controller-manager
    sudo mv kube-controller-manager /usr/local/bin/
    sudo mv kube-controller-manager.kubeconfig /var/lib/kubernetes/
  }

  # move kube-controller-manager service systemd unit file
  sudo mv kube-controller-manager.service /etc/systemd/system/kube-controller-manager.service

  # start kube-controller-manager
  echo "Started start of kube-controller-manager"
  {
    sudo systemctl daemon-reload
    sudo systemctl enable kube-controller-manager
    sudo systemctl start kube-controller-manager
  }
  echo "Completed start of kube-controller-manager"
  echo "Completed installation of kube-controller-manager"
fi