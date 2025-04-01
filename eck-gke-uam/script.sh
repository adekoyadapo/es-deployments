#!/bin/bash

cleanup() {
  echo -e "Cleaning up Terraform state files...\n"

  find . -type d -name ".terraform" -exec rm -rf {} +
  find . -type f -name "terraform.tfstate*" -exec rm -f {} +
  find . -type f -name ".terraform.lock.hcl" -exec rm -f {} +

  echo -e "Cleanup completed.\n"
}

if [ "$1" = "deploy" ]; then
  echo -e "Setting up infra\n"

  terraform -chdir=infra init
  echo
  echo -e "Creating Cluster in GKE\n"
  terraform -chdir=infra apply
  sleep 10
  echo
  echo -e "Creating Deployments\n"
  terraform -chdir=deployments init
  terraform -chdir=deployments apply

elif [ "$1" = "destroy" ]; then
  echo
  echo -e "Destroying resources\n"

  terraform -chdir=deployments destroy -auto-approve
  sleep 10 
  terraform -chdir=infra destroy -auto-approve

  cleanup

else
  echo -e "Invalid argument. Please use './script deploy' to setup resources or './script destroy' to clean up resources."
fi