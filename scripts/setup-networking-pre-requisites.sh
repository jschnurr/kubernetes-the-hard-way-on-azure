#!/bin/bash
# remotely executed script
# $1 - current worker node number to be setup

cd ~

echo "Started installation of socat binary"
# install socat binary to enable 'kubectl port-forward' command (inside worker node)
{
  sudo apt-get update
  sudo apt-get -y install socat conntrack ipset
}
echo "Completed installation of socat binary"

# disable swap
sudo swapoff -a

# if cni is already installed
if [ -d /etc/cni ]
then
  echo "Found cni plugin as already installed"
  # remove files copied already from remote
  rm 10-bridge.conf 99-loopback.conf
else
  echo "Not found cni plugin as installed"

  # download cni plugin v0.8.5
  echo "Started installation of cni plugin"
  wget --progress=bar:force:noscroll --https-only \
    "https://github.com/containernetworking/plugins/releases/download/v0.8.5/cni-plugins-linux-amd64-v0.8.5.tgz"

  # configure cni plugin
  {
  sudo mkdir -p \
      /etc/cni/net.d \
      /opt/cni/bin
  sudo tar -xvf cni-plugins-linux-amd64-v0.8.5.tgz -C /opt/cni/bin/
  rm cni-plugins-linux-amd64-v0.8.5.tgz
  }

  # prepare cni configuration files

  # substitute the value for <POD_CIDR>
  sed -i "s|<POD_CIDR>|10.200.$1.0\/24|g" 10-bridge.conf

  # move cni configuration files
  sudo mv 10-bridge.conf 99-loopback.conf /etc/cni/net.d/
  echo "Completed installation of cni plugin"
fi