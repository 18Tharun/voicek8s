# SSL/TLS Certificate Requirements

The deployment includes automatic SSL certificate generation using Let's Encrypt, but requires:

## Domain Verification
- **Valid domain name** pointing to your droplet IP
- **Public internet access** to your domain on port 80 (for verification)

## Email Address (for Let's Encrypt)
- **Admin email**: Used for certificate expiry notifications
- **Default**: admin@yourdomain.com (automatically set based on your domain)

## Certificate Renewal
- **Automatic renewal**: Handled by cert-manager
- **Validity period**: 90 days
- **Renewal occurs**: Approximately 30 days before expiry

## Manual Certificate Options
If using your own certificates instead of Let's Encrypt:
1. Create Kubernetes secret with your certificate files
2. Update the `kubernetes/ingress.yaml` file to use your certificate secret
