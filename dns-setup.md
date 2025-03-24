# DNS Configuration for Voice AI Application

## DNS Requirements:

To properly configure DNS for your Voice AI application, you'll need:

1. **A registered domain name** (from any domain registrar like Namecheap, GoDaddy, etc.)
2. **Access to your domain's DNS settings**
3. **Your DigitalOcean droplet's IP address**: $(cat /root/droplet_ip.txt)

## DNS Configuration Steps:

### Option 1: Using Root Domain (example.com)

Add an A record pointing to your droplet's IP address:
- **Type**: A
- **Name**: @ (or leave blank, depends on provider)
- **Value**: $(cat /root/droplet_ip.txt)
- **TTL**: 3600 (or lower like 300 for faster propagation)

### Option 2: Using Subdomain (app.example.com)

Add an A record for the subdomain:
- **Type**: A
- **Name**: app (or your desired subdomain)
- **Value**: $(cat /root/droplet_ip.txt)
- **TTL**: 3600 (or lower like 300)

### Option 3: Using DigitalOcean DNS

If your domain is managed through DigitalOcean DNS:

1. Go to DigitalOcean Control Panel
2. Click on "Networking" → "Domains"
3. Select your domain or add it
4. Add an A record as described above

## Verification:

After adding DNS records (allow 5-30 minutes for propagation):

1. Verify with:
   