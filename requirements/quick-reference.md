# Quick Reference for Required Information

| Requirement | Description | Where Used |
|-------------|-------------|-----------|
| DigitalOcean API Token | Personal access token with read/write permissions | Terraform deployment |
| Domain Name | Your application domain (optional but recommended) | Ingress, SSL, DNS setup |
| SSH Key Pair | For secure access to droplet | Terraform, direct access |
| MySQL Root Password | Database administrator password | Database init, connection testing |
| Docker Hub Credentials | If using private images (optional) | Image pull secrets |
| Droplet Size | Minimum s-2vcpu-4gb recommended | Terraform configuration |
| Region | DigitalOcean datacenter location | Terraform configuration |

## Environment Variables Summary

| Variable Name | Required | Description |
|---------------|----------|-------------|
| DO_TOKEN | Yes | DigitalOcean API token |
| TF_VAR_domain_name | No | Your application domain |
| TF_VAR_ssh_public_key_path | No | Path to SSH public key |
| TF_VAR_ssh_private_key_path | No | Path to SSH private key |
| MYSQL_ROOT_PASSWORD | No | Database password for tests |

## Automated Setup
Run the all-in-one deployment script to be prompted for these values:
```bash
./deploy-all.sh
```
