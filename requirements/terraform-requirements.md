# Terraform and Kubernetes Configuration

## Required Software
- **Terraform**: Version 1.0.0 or higher
  - Download: https://www.terraform.io/downloads.html
- **kubectl**: Version 1.18.0 or higher
  - Installation: https://kubernetes.io/docs/tasks/tools/install-kubectl/

## Terraform Variables
All variables are defined in `terraform/variables.tf` with these defaults:

1. **Environment Settings**:
   - `environment`: "prod" (can be changed to "dev" or "staging")
   - `region`: "nyc1" (change to your preferred DigitalOcean region)

2. **Droplet Configuration**:
   - `droplet_size`: "s-2vcpu-4gb" (recommended minimum)
   - `node_count`: 2 (minimum for high availability)

3. **Kubernetes Settings**:
   - `kubernetes_version`: "1.27.4-do.0" (latest stable at time of writing)
   - `cluster_name`: "voice-ai-cluster"

## Custom Settings
To override defaults:
- Create a `terraform/terraform.tfvars` file with your custom values
- Or set TF_VAR_* environment variables
