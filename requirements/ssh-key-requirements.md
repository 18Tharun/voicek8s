# SSH Key Requirements

SSH keys are required for secure access to your droplet and for Terraform to deploy resources.

## Options
1. **Use existing SSH key pair**:
   - Default location: `~/.ssh/id_rsa` (private) and `~/.ssh/id_rsa.pub` (public)
   - If you wish to use existing keys, ensure they're in the OpenSSH format

2. **Generate new key pair**:
   - Our deployment script can generate this automatically
   - Will be saved as `~/.ssh/voice_ai_key` and `~/.ssh/voice_ai_key.pub`

## Manual Key Generation
If you need to create keys manually:
