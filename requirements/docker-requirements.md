# Docker Hub Requirements

## For Public Images
If using only public Docker images (default configuration):
- No authentication required
- Our deployment uses these public images by default:
  - abhishekanbu01/db5:latest
  - abhishekanbu01/frontend2:latest
  - abhishekanbu01/parallel:latest
  - abhishekanbu01/voice2-metrics:latest

## For Private Images
If your Docker images are in a private repository:

1. **Docker Hub account credentials**:
   - Username: Your Docker Hub username
   - Password: Your Docker Hub password or access token

2. **Create a Kubernetes Secret**:
   Base64 encode your Docker Hub credentials:
   ```
   echo -n '{"auths":{"https://index.docker.io/v1/":{"username":"YOUR_USERNAME","password":"YOUR_PASSWORD","auth":"BASE64_ENCODED_USERNAME_PASSWORD"}}}' | base64
   ```
   
3. **Update Pull Secret**:
   Replace the placeholder in `kubernetes/image-pull-secrets.yaml` with your encoded credentials

4. **Apply Secret**:
   ```
   kubectl apply -f kubernetes/image-pull-secrets.yaml
   ```
