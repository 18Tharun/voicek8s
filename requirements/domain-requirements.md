# Domain Name Requirements

## Domain Name Options
1. **Use an existing domain**: Configure a subdomain like `voice.yourdomain.com`
2. **Purchase new domain**: Can be acquired from any registrar (Namecheap, GoDaddy, etc.)

## Domain Management Options
- **Option 1: DigitalOcean DNS**
  - Add domain at https://cloud.digitalocean.com/networking/domains
  - Allows direct integration with DigitalOcean services
  
- **Option 2: External DNS Provider**
  - Keep domain at your current registrar
  - You'll need to create appropriate DNS records

## Required DNS Records
- **A Record**:
  - Type: A
  - Name: @ (root) or subdomain name (e.g., voice)
  - Value: Your droplet's IP address
  - TTL: 3600 (or lower like 300 for testing)
  
- **CNAME Record** (optional for www subdomain):
  - Type: CNAME
  - Name: www
  - Value: @ or your domain name with a trailing dot
  - TTL: 3600
