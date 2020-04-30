#!/bin/bash
# $1 total master nodes
# $2 master node number
# $3 prefix
# $4 environment

cd ~

# prepare etcd service systemd unit file

# substitute the value for <HOSTNAME>
sed -i "s|<HOSTNAME>|$(hostname -s)|g" etcd.service

# substitute the value for <INTERNAL_IP>
sed -i "s|<INTERNAL_IP>|$(hostname -i)|g" etcd.service

# replace the initial cluster value in etcd.service
new_value=""
for (( i=1; i<=$1; i++ ))
do
  new_value+="$3-$4-mastervm0$i=https://10.240.0.1$i:2380,"
done
new_value=${new_value%,}
old_value=$(grep -oP "^\s+--initial-cluster\s+\K.*(?=\s+\\\\$)" etcd.service)
sed -i "s|--initial-cluster $old_value|--initial-cluster $new_value|g" etcd.service

# replace the initial cluster state value in etcd.service
# if not mastervm01
if [ $2 -ne 1 ]
then
  # join existing cluster mode in mastervm02, mastervm03 ...
  new_value="existing"
# if mastervm01
else
  # new initial cluster mode in mastervm01
  new_value="new"
fi
old_value=$(grep -oP "^\s+--initial-cluster-state\s+\K.*(?=\s+\\\\$)" etcd.service)
sed -i "s|--initial-cluster-state $old_value|--initial-cluster-state $new_value|g" etcd.service

# move etcd service systemd unit file
sudo mv etcd.service /etc/systemd/system/etcd.service

# if etcd service is already installed
if systemctl list-unit-files | grep -q "^etcd.service";
then
  # remove files copied already from remote
  rm ca.crt etcd-server.crt etcd-server.key

  # if not mastervm01
  if [ $2 -ne 1 ]
  then
    # refresh data on existing members - mastervm02, mastervm03 etc.

    # stop etcd server
    {
      sudo systemctl daemon-reload
      sudo systemctl stop etcd
    }

    # delete existing data
    sudo rm /var/lib/etcd/member/ -r

    # restart etcd server
    {
      sudo systemctl daemon-reload
      sudo systemctl restart etcd
    }
  # if mastervm01
  else
    # add existing members - mastervm02, mastervm03 etc. to initial cluster on mastervm01

    # restart etcd server
    {
      sudo systemctl daemon-reload
      sudo systemctl restart etcd
    }

    for (( i=2; i<=$1; i++ ))
    do
      sudo ETCDCTL_API=3 etcdctl member add \
        kthw-play-mastervm0$i --peer-urls=https://10.240.0.1$i:2380 \
        --endpoints=https://127.0.0.1:2379 \
        --cacert=/etc/etcd/ca.crt \
        --cert=/etc/etcd/etcd-server.crt \
        --key=/etc/etcd/etcd-server.key
    done
  fi
else
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

  # configure etcd server
  {
    sudo mkdir -p /etc/etcd /var/lib/etcd
    sudo mv ca.crt etcd-server.crt etcd-server.key /etc/etcd/
  }

  # start etcd server
  {
    sudo systemctl daemon-reload
    sudo systemctl enable etcd
    sudo systemctl start etcd
  }
fi

# verify etcd server
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.crt \
  --cert=/etc/etcd/etcd-server.crt \
  --key=/etc/etcd/etcd-server.key