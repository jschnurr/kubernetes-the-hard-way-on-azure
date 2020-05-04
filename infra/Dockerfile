FROM ubuntu:bionic

# update debian package list and upgrade installed packages via apt
RUN apt-get update && \
    apt-get full-upgrade -y

# install basic utilities
RUN apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl wget unzip tar openssl ssh nano \
        lsb-release \
        gnupg-agent gnupg2 \
        software-properties-common

# install azure cli tool
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# install kubectl
RUN curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update && \
    apt-get install -y kubectl

# install terraform
RUN wget https://releases.hashicorp.com/terraform/0.12.24/terraform_0.12.24_linux_amd64.zip && \
    unzip terraform_0.12.24_linux_amd64.zip && \
    mv terraform /usr/local/bin/ && \
    rm terraform_0.12.24_linux_amd64.zip