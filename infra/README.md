# Install basic and docker pre-requisites

## - Choose the running platform
For Windows 10, there are 2 options:
1. Windows Subsystem for Linux (WSL)*: https://docs.microsoft.com/en-us/windows/wsl/install-win10  
2. Or, WSL2*: https://docs.microsoft.com/en-us/windows/wsl/wsl2-install  
*choose Ubuntu 18.04 LTS distro either way

For Linux, there are 2 options:
1. Ubuntu 18.04.4 LTS (Bionic Beaver): https://releases.ubuntu.com/18.04.4/  
2. Or, Ubuntu 20.04 LTS (Focal Fossa): https://releases.ubuntu.com/20.04/  

## - Change directory to home in bash terminal
```
cd ~
```

## - Update and upgrade apt packages:
```
{
  sudo apt-get update
  sudo apt-get full-upgrade -y
}
```

## - Install basic prereuisites:
```
sudo apt-get install -y \
     apt-transport-https \
     ca-certificates \
     curl wget unzip tar openssl git \
     lsb-release \
     gnupg-agent gnupg2 \
     software-properties-common
```

## - Clean kthw-azure-git directory, if already exists
```
rm ~/kthw-azure-git -rf
```

## - Clone git repo into kthw-azure git directory
```
git clone https://github.com/ankursoni/kubernetes-the-hard-way-on-azure.git ~/kthw-azure-git
```

---
---

# Install remaining pre-requisites as docker image (recommended)

## - Install docker ce on WSL:
1. Install Docker for Windows: https://docs.docker.com/docker-for-windows/install  
2. Enable docker integration in WSL:  
a. https://docs.microsoft.com/en-us/virtualization/community/team-blog/2017/20171208-wsl-interoperability-with-docker  
b. Or, https://nickjanetakis.com/blog/setting-up-docker-for-windows-and-wsl-to-work-flawlessly

## - Install docker ce on WSL2:
1. Install Docker for Windows: https://docs.docker.com/docker-for-windows/install  
2. Enable docker integration in WSL2: https://code.visualstudio.com/blogs/2020/03/02/docker-in-wsl2

## - Install docker ce on Ubuntu 18.04:
```
{
  curl -fsSL "https://download.docker.com/linux/$(lsb_release -is | tr -td '\n' | tr [:upper:] [:lower:])/gpg" | sudo apt-key add -

  echo "deb [arch=amd64] https://download.docker.com/linux/$(lsb_release -is | tr -td '\n' | tr [:upper:] [:lower:]) \
  $(lsb_release -cs | tr -td '\n' | tr [:upper:] [:lower:]) stable" | sudo tee -a /etc/apt/sources.list.d/docker.list

  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io
}
```

## - Install docker on Ubuntu 20.04:
```
sudo apt-get install docker-compose
```

## - Build docker image with the image name as kthw-azure-image
```
cd ~/kthw-azure-git/infra
docker build -t kthw-azure-image .
```

## - Run docker container in interactive terminal with kthw-azure-git directory mounted from the host machine
```
docker run -it --rm --name=kthw-azure-container --mount type=bind,source=$HOME/kthw-azure-git,target=/root/kthw-azure-git kthw-azure-image bash
```

# Or, install remaining pre-requisites directly on host (not recommended)

## - Change directory to home
```
cd ~
```

## - Install az cli
```
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

## - Install kubectl
```
{
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
  echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
  sudo apt-get update
  sudo apt-get install -y kubectl
}
```

## - Install terraform
```
{
  wget https://releases.hashicorp.com/terraform/0.12.24/terraform_0.12.24_linux_amd64.zip
  unzip terraform_0.12.24_linux_amd64.zip
  sudo mv terraform /usr/local/bin/
  rm terraform_0.12.24_linux_amd64.zip
}
```

## - Verify terraform installation
```
terraform -v
```

---
---

# Provision environment
```
cd ~/kthw-azure-git/infra
terraform init
terraform apply -var-file=azurerm-secret.tfvars
```

# NOTE

## - Set the values for the variables by writing to the var file - azurerm-secret.tfvars:
```
az login
az account list
# note the id as <SUBSCRIPTION_ID> and tenantId as <TENANT_ID> from the output of previous command

# generate an azure service principal with contributor permissions, if you don't already have one:
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/<SUBSCRIPTION_ID>"
# note the appId as <CLIENT_ID> and password as <CLIENT_SECRET> from the output of previous command

# generate an ssh key, if you don't already have one:
ssh-keygen -b 4096 -t rsa -C <EMAIL_ADDRESS>

# note the path of the file "~/.ssh/id_rsa.pub" as <SSH_PUBLIC_KEY_FILE>

# copy the template variable file
cd ~/kthw-azure-git/infra
cp azurerm.tfvars azurerm-secret.tfvars

# substitute the value for <SUBSCRIPTION_ID> by replacing VALUE in the following command:
sed -i 's/<SUBSCRIPTION_ID>/VALUE/g' azurerm-secret.tfvars
# for e.g., the command to substitute the value for <SUBSCRIPTION_ID> with 794a7d2a-565a-4ebd-8dd9-0439763e6b55 as VALUE looks like this:
sed -i 's/<SUBSCRIPTION_ID>/794a7d2a-565a-4ebd-8dd9-0439763e6b55/g' azurerm-secret.tfvars

# substitute the value for <TENANT_ID> by replacing VALUE in the following command:
sed -i 's/<TENANT_ID>/VALUE/g' azurerm-secret.tfvars

# substitute the value for <CLIENT_ID> by replacing VALUE in the following command:
sed -i 's/<CLIENT_ID>/VALUE/g' azurerm-secret.tfvars

# substitute the value for <CLIENT_SECRET> by replacing VALUE in the following command:
sed -i 's/<CLIENT_SECRET>/VALUE/g' azurerm-secret.tfvars

# substitute the value for <SSH_PUBLIC_KEY_FILE> by replacing VALUE in the following command:
# VALUE e.g. "~/.ssh/id_rsa.pub"
sed -i 's/<SSH_PUBLIC_KEY_FILE>/VALUE/g' azurerm-secret.tfvars

# substitute the value for <ENVIRONMENT> by replacing VALUE in the following command:
# VALUE e.g. "play" or "poc" or "dev" or "demo" etc.
sed -i 's/<ENVIRONMENT>/VALUE/g' azurerm-secret.tfvars

# substitute the value for <LOCATION> by replacing VALUE in the following command:
# VALUE e.g. "Australia East" or "Southeast Asia" or "Central US" etc. - for more, run "az account list-locations -o table"
sed -i 's/<LOCATION>/VALUE/g' azurerm-secret.tfvars

# substitute the value for <PREFIX> by replacing VALUE in the following command:
# VALUE e.g. "kthw" or "kube" etc.
sed -i 's/<PREFIX>/VALUE/g' azurerm-secret.tfvars

# substitute the value for <MASTER_VM_SIZE> by replacing VALUE in the following command:
# VALUE e.g. "Standard_B1ms" - for more, run "az vm list-sizes --location "<LOCATION>" -o table"
sed -i 's/<MASTER_VM_SIZE>/VALUE/g' azurerm-secret.tfvars

# substitute the value for <MASTER_VM_COUNT> by replacing VALUE in the following command:
# VALUE e.g. 1 or 2 etc.
sed -i 's/<MASTER_VM_COUNT>/VALUE/g' azurerm-secret.tfvars

# substitute the value for <WORKER_VM_SIZE> by replacing VALUE in the following command:
# VALUE e.g. "Standard_B1ms" - for more, run "az vm list-sizes --location "<LOCATION>" -o table"
sed -i 's/<WORKER_VM_SIZE>/VALUE/g' azurerm-secret.tfvars

# substitute the value for <WORKER_VM_COUNT> by replacing VALUE in the following command:
# VALUE e.g. 1 or 2 etc.
sed -i 's/<WORKER_VM_COUNT>/VALUE/g' azurerm-secret.tfvars