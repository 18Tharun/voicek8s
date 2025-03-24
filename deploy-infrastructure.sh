#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting Voice AI infrastructure deployment on DigitalOcean...${NC}"

# Check for required tools
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Terraform is not installed! Please install it first.${NC}"
    exit 1
fi

if ! command -v doctl &> /dev/null; then
    echo -e "${RED}doctl is not installed! Please install DigitalOcean CLI first.${NC}"
    exit 1
fi

# Ask for DigitalOcean API token if not set
if [ -z "$DO_TOKEN" ]; then
    read -sp "Enter your DigitalOcean API token: " DO_TOKEN
    echo
    
    if [ -z "$DO_TOKEN" ]; then
        echo -e "${RED}API token cannot be empty!${NC}"
        exit 1
    fi
    
    export DO_TOKEN
    export TF_VAR_do_token=$DO_TOKEN
fi

# Step 1: Create infrastructure with Terraform
echo -e "${YELLOW}Creating infrastructure with Terraform...${NC}"
cd terraform

# Initialize, plan, and apply
terraform init
terraform validate
echo -e "${YELLOW}Planning infrastructure (this may take a moment)...${NC}"
terraform plan -out=tfplan

echo -e "${GREEN}Ready to create the following resources:${NC}"
echo -e "- Kubernetes cluster with 2 nodes (s-2vcpu-4gb)"
echo -e "- Container registry for your Docker images"
echo -e "- Autoscaling configuration (2-4 nodes)"
echo
read -p "Continue with deployment? (y/n): " CONTINUE

if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deployment cancelled.${NC}"
    exit 0
fi

echo -e "${YELLOW}Creating infrastructure (this will take several minutes)...${NC}"
terraform apply tfplan

# Configure kubectl
echo -e "${YELLOW}Configuring kubectl to use the new cluster...${NC}"
mkdir -p ~/.kube
terraform output -raw kubeconfig > ~/.kube/config
chmod 600 ~/.kube/config

# Save cluster ID for future reference
CLUSTER_ID=$(terraform output -raw cluster_id)
echo "$CLUSTER_ID" > ../cluster_id.txt

cd ..

echo -e "${GREEN}Infrastructure successfully created!${NC}"
echo -e "Kubernetes cluster is now ready for deployment."
echo -e "\nTo deploy your application, run:"
echo -e "${YELLOW}./deploy.sh${NC}"

echo -e "\nTo get information about your cluster, run:"
echo -e "${YELLOW}kubectl cluster-info${NC}"
echo -e "${YELLOW}kubectl get nodes${NC}"
