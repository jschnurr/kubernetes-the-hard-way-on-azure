#!/bin/bash
# remotely executed script

cd ~

# if containerd is already installed
if systemctl list-unit-files | grep -q "^containerd.service"
then
  echo "Found containerd as already installed"
  # remove files copied already from remote
  rm config.toml

  # move containerd systemd unit file
  sudo mv containerd.service /etc/systemd/system/containerd.service

  # restart containerd
  echo "Started restart of containerd"
  {
    sudo systemctl daemon-reload
    sudo systemctl restart containerd
  }
  echo "Completed restart of containerd"

# else containerd is not installed
else
  echo "Not found containerd as installed"

  # download containerd v1.2.13
  echo "Started installation of containerd"
  wget --progress=bar:force:noscroll --https-only \
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

  # start containerd
  echo "Started start of containerd"
  {
    sudo systemctl daemon-reload
    sudo systemctl enable containerd
    sudo systemctl start containerd
  }
  echo "Completed start of containerd"
  echo "Completed installation of containerd"
fi