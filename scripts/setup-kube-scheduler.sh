#!/bin/bash

cd ~

# if kube-scheduler service is already installed
if systemctl list-unit-files | grep -q "^kube-scheduler.service"
then
  echo "Found kube-scheduler as already installed"
  # remove files copied already from remote
  rm kube-scheduler.kubeconfig

  # move kube-scheduler service systemd unit file
  sudo mv kube-scheduler.service /etc/systemd/system/kube-scheduler.service

  # restart kube-scheduler
  echo "Started restart of kube-scheduler"
  {
    sudo systemctl daemon-reload
    sudo systemctl restart kube-scheduler
  }
  echo "Completed restart of kube-scheduler"

# else kube-scheduler service is not installed
else
  echo "Not found kube-scheduler as installed"

  # download kube-scheduler v1.18.1
  echo "Started installation of kube-scheduler"
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

  # start kube-scheduler
  echo "Started start of kube-scheduler"
  {
    sudo systemctl daemon-reload
    sudo systemctl enable kube-scheduler
    sudo systemctl start kube-scheduler
  }
  echo "Completed start of kube-scheduler"
  echo "Completed installation of kube-scheduler"
fi