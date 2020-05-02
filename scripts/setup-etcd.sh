#!/bin/bash
# $1 total master nodes
# $2 current master node number to be setup
# $3 prefix
# $4 environment

cd ~

# prepare etcd service systemd unit file
echo "Started preparation of etcd service systemd unit file"

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
echo "Completed preparation of etcd service systemd unit file"

# if etcd service is already installed
if systemctl list-unit-files | grep -q "^etcd.service"
then
  echo "Found etcd as already installed"
  # remove files copied already from remote
  rm ca.crt etcd-server.crt etcd-server.key

  # move etcd service systemd unit file
  sudo mv etcd.service /etc/systemd/system/etcd.service

  # if not mastervm01
  if [ $2 -ne 1 ]
  then
    # refresh data on existing members - mastervm02, mastervm03 etc.
    echo "Started refresh of etcd member data"
    # stop etcd server
    {
      sudo systemctl daemon-reload
      sudo systemctl stop etcd
    }

    # delete existing data
    sudo rm /var/lib/etcd/member/ -r

    # restart etcd server
    echo "Started restart of etcd server"
    {
      sudo systemctl daemon-reload
      sudo systemctl restart etcd
    }
    echo "Completed restart of etcd server"
    echo "Completed refresh of etcd member data"

  # if mastervm01
  else
    # restart etcd server
    echo "Started restart of etcd server"
    {
      sudo systemctl daemon-reload
      sudo systemctl restart etcd
    }
    echo "Completed restart of etcd server"

    # add existing members - mastervm02, mastervm03 etc. to initial cluster on mastervm01
    echo "Started addition of etcd members"

    for (( i=2; i<=$1; i++ ))
    do
      # check for mastervm in the member list
      echo "Started checking of etcd member - $3-$4-mastervm0$i"
      member=$(sudo ETCDCTL_API=3 etcdctl member list \
          --endpoints=https://127.0.0.1:2379 \
          --cacert=/etc/etcd/ca.crt \
          --cert=/etc/etcd/etcd-server.crt \
          --key=/etc/etcd/etcd-server.key \
        | grep -oP "^.*mastervm0$i")
      
      # if mastervm exists in the member list
      if [ ! -z "$member" ]
      then
        # collect the member id and status
        member_id=$(echo $member | grep -oP "^\w+")
        member_status=$(echo $member | grep -oP "^$member_id,\s\K\w+")

        echo "Found existing etcd member - mastervm0$i in $member_status status"

        # if member is not in started status
        if [ "$member_status" != "started" ]
        then
          # remove the mastervm from the member list
          echo "Removing existing etcd member - $3-$4-mastervm0$i"
          sudo ETCDCTL_API=3 etcdctl member remove \
            $member_id \
            --endpoints=https://127.0.0.1:2379 \
            --cacert=/etc/etcd/ca.crt \
            --cert=/etc/etcd/etcd-server.crt \
            --key=/etc/etcd/etcd-server.key

          # add mastervm to the member list again
          echo "Adding existing etcd member - $3-$4-mastervm0$i"
          sudo ETCDCTL_API=3 etcdctl member add \
            kthw-play-mastervm0$i --peer-urls=https://10.240.0.1$i:2380 \
            --endpoints=https://127.0.0.1:2379 \
            --cacert=/etc/etcd/ca.crt \
            --cert=/etc/etcd/etcd-server.crt \
            --key=/etc/etcd/etcd-server.key
          
          sleep 5
        fi
      else
        echo "Not found etcd member - $3-$4-mastervm0$i"

        # add mastervm to the member list for the first time
        echo "Adding existing etcd member - $3-$4-mastervm0$i"
        sudo ETCDCTL_API=3 etcdctl member add \
          kthw-play-mastervm0$i --peer-urls=https://10.240.0.1$i:2380 \
          --endpoints=https://127.0.0.1:2379 \
          --cacert=/etc/etcd/ca.crt \
          --cert=/etc/etcd/etcd-server.crt \
          --key=/etc/etcd/etcd-server.key
        
        sleep 5
      fi
    done
    echo "Completed addition of etcd members"
  fi

# else etcd service is not installed
else
  echo "Not found etcd as installed"

  # download etcd v3.4.7
  echo "Started installation of etcd"
  wget --progress=bar:force:noscroll --https-only \
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

  # if mastervm01
  if [ $2 -eq 1 ]
  then
    # replace the initial cluster value in etcd.service as just the mastervm01
    new_value="$3-$4-mastervm01=https://10.240.0.11:2380"
    old_value=$(grep -oP "^\s+--initial-cluster\s+\K.*(?=\s+\\\\$)" etcd.service)
    sed -i "s|--initial-cluster $old_value|--initial-cluster $new_value|g" etcd.service
  fi

  # move etcd service systemd unit file
  sudo mv etcd.service /etc/systemd/system/etcd.service

  # start etcd server
  echo "Started start of etcd server"
  {
    sudo systemctl daemon-reload
    sudo systemctl enable etcd
    sudo systemctl start etcd
  }
  echo "Completed start of etcd server"

  # if mastervm01
  if [ $2 -eq 1 ]
  then
    for (( i=2; i<=$1; i++ ))
    do
      # add mastervm to the member list again
      echo "Adding existing etcd member - $3-$4-mastervm0$i"
      sudo ETCDCTL_API=3 etcdctl member add \
        kthw-play-mastervm0$i --peer-urls=https://10.240.0.1$i:2380 \
        --endpoints=https://127.0.0.1:2379 \
        --cacert=/etc/etcd/ca.crt \
        --cert=/etc/etcd/etcd-server.crt \
        --key=/etc/etcd/etcd-server.key
    done

    sleep 5
  fi
  echo "Completed installation of etcd"
fi

if [ $2 -eq 1 ]
then
  # verify etcd server on mastervm01
  echo "Displaying etcd member list"
  sudo ETCDCTL_API=3 etcdctl member list \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/etcd/ca.crt \
    --cert=/etc/etcd/etcd-server.crt \
    --key=/etc/etcd/etcd-server.key
fi