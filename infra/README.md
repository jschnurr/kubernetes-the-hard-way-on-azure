# Install basic and docker pre-requisites

## - Change directory to home
```
cd ~
```

## - Update and upgrade apt packages:
```
sudo apt-get update
sudo apt-get full-upgrade -y
```

## - Install basic prereuisites:
```
sudo apt-get install -y \
     apt-transport-https \
     ca-certificates \
     curl wget unzip tar openssl git \
     lsb-release \
     gnupg-agent \
     software-properties-common
```

## - Install docker ce:
```
curl -fsSL "https://download.docker.com/linux/$(lsb_release -is | tr -td '\n' | tr [:upper:] [:lower:])/gpg" | sudo apt-key add -

sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$(lsb_release -is | tr -td '\n' | tr [:upper:] [:lower:]) \
$(lsb_release -cs | tr -td '\n' | tr [:upper:] [:lower:]) stable"

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli
```

## - Clean ktwh-azure directory, if already exists
```
rm ~/ktwh-azure-git -rf
```

## - Clone git repo into ktwh-azure git directory
```
git clone https://github.com/ankursoni/kubernetes-the-hard-way-on-azure.git ~/ktwh-azure-git
```

# Install remaining pre-requisites as docker image (recommended)

## - Build docker image with the image name as ktwh-azure-image
```
cd ~/ktwh-azure-git/infra
docker build -t ktwh-azure-image .
```

## - Run docker in interactive terminal with ktwh-azure-git directory mounted from the host machine
```
docker run -it --rm --name=ktwh-azure-container --mount type=bind,source=$HOME/ktwh-azure-git,target=/root/ktwh-azure-git ktwh-azure-image bash
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

## - Install terraform from https://learn.hashicorp.com/terraform/getting-started/install.html to find the latest package (v0.12.24 at the time of writing):
```
wget https://releases.hashicorp.com/terraform/0.12.24/terraform_0.12.24_linux_amd64.zip
unzip terraform_0.12.24_linux_amd64.zip
sudo mv terraform /usr/local/bin/
rm terraform_0.12.24_linux_amd64.zip
```

## - Verify terraform installation
```
terraform -v
```

# Provision environment
```
az login
cd ~/ktwh-azure-git/infra
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

# substitute the values inside <> as appropriate
cat >~/ktwh-azure-git/infra/azurerm-secret.tfvars <<EOF
subscription_id = "<SUBSCRIPTION_ID>"
tenant_id = "<TENANT_ID>"
client_id = "<CLIENT_ID>"
client_secret = "<CLIENT_SECRET>"
environment = "<ENVIRONMENT>" (e.g. "play" or "poc" or "dev" or "test" etc.)
location = "<LOCATION>" (e.g. "Australia East" or "Southeast Asia" etc.)
ssh_key_file = "<SSH_PUBLIC_KEY_FILE>"
EOF
```