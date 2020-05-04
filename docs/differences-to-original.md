# Differences between original and this solution

Platform -
* this project uses Azure to setup a cluster, the original one uses Google Cloud Platform (GCP).

Tools -
* this project uses terraform automation scripts to provision infrastructure, the original one uses gcloud cli tool,
* this project uses bash shell scripts to automate many tasks for tutorial,
* this project uses openssl to generate certificates.

Installation -
* this project uses kubernetes v1.18.1, latest as of April 2020,
* this project uses TLS bootstrapping for worker nodes,
* this project provides fully automated end to end provisioning and installation of cluster.