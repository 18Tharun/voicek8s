#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== VOICE AI COMPLETE DEPLOYMENT SYSTEM ===${NC}"

# Check if required tools are installed
for tool in terraform ssh-keygen; do
  if ! command -v $tool &> /dev/null; then
    echo -e "${RED}$tool is not installed. Please install it and try again.${NC}"
    exit 1
  fi
done

# Generate SSH key if it doesn't exist
SSH_KEY_PATH="$HOME/.ssh/voice_ai_key"
if [ ! -f "${SSH_KEY_PATH}" ]; then
  echo -e "${YELLOW}Generating SSH key pair for deployment...${NC}"
  ssh-keygen -t rsa -b 4096 -f "${SSH_KEY_PATH}" -N "" -C "voice_ai_deployment_key"
  echo -e "${GREEN}SSH key pair generated at ${SSH_KEY_PATH}${NC}"
fi

# Ask for DigitalOcean API token if not already set
if [ -z "$DO_TOKEN" ]; then
  read -sp "Enter your DigitalOcean API token: " DO_TOKEN
  echo
  export DO_TOKEN
fi

# Ask for domain name
read -p "Enter your domain name (leave blank to use IP address): " DOMAIN_NAME

# Create terraform.tfvars file
cat > terraform/terraform.tfvars <<EOF
do_token = "${DO_TOKEN}"
ssh_public_key_path = "${SSH_KEY_PATH}.pub"
ssh_private_key_path = "${SSH_KEY_PATH}"
domain_name = "${DOMAIN_NAME}"
EOF

echo -e "${YELLOW}Starting infrastructure deployment with Terraform...${NC}"

# Initialize and apply Terraform
cd terraform
terraform init
terraform apply -auto-approve

echo -e "${GREEN}Terraform deployment complete!${NC}"

# Display outputs
echo -e "${YELLOW}=== DEPLOYMENT INFORMATION ===${NC}"
echo -e "Droplet IP: $(terraform output -raw droplet_ip)"
echo -e "Access your application at: $(terraform output -raw domain_name)"
echo -e "To SSH into your server: $(terraform output -raw ssh_command)"

echo -e "\n${GREEN}=== DEPLOYMENT SUCCESSFUL ===${NC}"
echo -e "Your Voice AI system has been completely deployed and is ready to use!"
echo -e "If you specified a domain name, please allow some time for DNS propagation."
