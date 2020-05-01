#!/bin/bash

cd ~

# download nginx latest version
echo "Started installation of nginx"
{
  sudo apt-get update
  sudo apt-get install -y nginx
}

# configure nginx service
{
  sudo mv healthprobe \
    /etc/nginx/sites-available/healthprobe

  sudo ln -s /etc/nginx/sites-available/healthprobe /etc/nginx/sites-enabled/
}

# restart nginx
echo "Started restart of nginx"
{
  sudo systemctl enable nginx
  sudo systemctl restart nginx
}
echo "Completed restart of nginx"
echo "Completed installation of nginx"

# verify http health check endpoint
echo "Displaying health check endpoint web request output"
curl -H "Host: kubernetes.default.svc.cluster.local" -i http://127.0.0.1/healthz