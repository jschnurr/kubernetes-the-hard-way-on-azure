#!/bin/bash

cd ~

# if kube-proxy service is already installed
if systemctl list-unit-files | grep -q "^kube-proxy.service"
then
  echo "Found kube-proxy as already installed"
  # remove files copied already from remote
  rm kube-proxy.kubeconfig kube-proxy-config.yaml

  # move kube-proxy service systemd unit file
  sudo mv kube-proxy.service /etc/systemd/system/kube-proxy.service

  # restart kube-proxy
  echo "Started restart of kube-proxy"
  {
    sudo systemctl daemon-reload
    sudo systemctl restart kube-proxy
  }
  echo "Completed restart of kube-proxy"

# else kube-proxy service is not installed
else
  echo "Not found kube-proxy as installed"

  # download kube-proxy v1.18.1
  echo "Started installation of kube-proxy"
  wget -q --show-progress --https-only --timestamping \
    "https://storage.googleapis.com/kubernetes-release/release/v1.18.1/bin/linux/amd64/kube-proxy"

  # configure kube-proxy service
  {
    sudo mkdir -p /var/lib/kube-proxy
    chmod +x kube-proxy
    sudo mv kube-proxy /usr/local/bin/
    sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
  }

  # move kube-proxy config file
  sudo mv kube-proxy-config.yaml /var/lib/kube-proxy/kube-proxy-config.yaml

  # move kube-proxy service systemd unit file
  sudo mv kube-proxy.service /etc/systemd/system/kube-proxy.service

  # start kube-proxy
  echo "Started start of kube-proxy"
  {
    sudo systemctl daemon-reload
    sudo systemctl enable kube-proxy
    sudo systemctl start kube-proxy
  }
  echo "Completed start of kube-proxy"
  echo "Completed installation of kube-proxy"
fi