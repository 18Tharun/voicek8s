# DigitalOcean Requirements

## Account Requirements
- **Active DigitalOcean account**: Sign up at https://cloud.digitalocean.com/registrations/new

## API Access
- **Personal Access Token**: 
  - Create at https://cloud.digitalocean.com/account/api/tokens
  - Required scopes: Read and Write
  - Recommended token name: `voice-ai-deployment`
  - **IMPORTANT**: Save this token securely; it's only shown once
  - Format: 32-character hexadecimal, e.g., `dop_v1_1234567890abcdef1234567890abcdef`

## Resource Requirements
- **Minimum droplet size**: Standard 4GB RAM / 2 vCPUs (s-2vcpu-4gb)
- **Region**: Choose closest to your target audience (e.g., nyc1, sfo3, fra1)
- **Estimated monthly cost**: ~$24/month for minimal setup
