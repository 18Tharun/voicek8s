#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting Voice AI deployment on DigitalOcean Kubernetes...${NC}"

# Step 1: Create infrastructure with Terraform
echo -e "${YELLOW}Creating infrastructure with Terraform...${NC}"
cd terraform
terraform init
terraform validate
terraform apply -auto-approve
echo -e "${GREEN}Infrastructure created successfully!${NC}"

# Step 2: Configure kubectl to use the new cluster
echo -e "${YELLOW}Configuring kubectl...${NC}"
mkdir -p ~/.kube
terraform output -raw kubeconfig > ~/.kube/config
chmod 600 ~/.kube/config
echo -e "${GREEN}kubectl configured successfully!${NC}"

# Step 3: Deploy Kubernetes resources
echo -e "${YELLOW}Deploying Kubernetes resources...${NC}"
cd ../kubernetes

# Apply resources in the correct order
kubectl apply -f namespace.yaml
echo "✅ Namespace created"

kubectl apply -f configmap.yaml
kubectl apply -f secrets.yaml
echo "✅ ConfigMap and Secrets created"

kubectl apply -f database-deployment.yaml
echo "✅ Database deployment created"

# Set up environment variables for database connection verification
DB_PASSWORD="my-secret-pw"
export DB_PASSWORD

# Wait for database to be ready
echo "Waiting for database to become ready..."
kubectl wait --for=condition=ready pod -l app=db --timeout=120s -n voice-ai

# After database deployment, verify connection if kubectl is available
if command -v kubectl &> /dev/null && command -v mysql &> /dev/null; then
  echo "Verifying database connection..."
  DB_POD=$(kubectl get pods -n voice-ai -l app=db -o jsonpath="{.items[0].metadata.name}")
  
  # Wait for database to be ready and verify connection
  kubectl wait --for=condition=ready pod $DB_POD -n voice-ai --timeout=120s
  kubectl exec -it $DB_POD -n voice-ai -- mysql -u root -p"$DB_PASSWORD" -e "SHOW DATABASES;"
  
  if [ $? -eq 0 ]; then
    echo "✅ Database connection verified"
  else
    echo "⚠️ Database connection verification failed, but continuing deployment"
  fi
fi

# After database deployment, print image info
echo "Using the following Docker images:"
echo "- Database: abhishekanbu01/db-working:latest (764MB)"
echo "- Frontend: abhishekanbu01/frontend2-working:latest (224MB)" 
echo "- Parallel Caller: abhishekanbu01/parallel2-working:latest (1.21GB)"
echo "- Voice Metrics: abhishekanbu01/voice2-metrics:latest (1.32GB)"

kubectl apply -f frontend-deployment.yaml
kubectl apply -f backend-services.yaml
kubectl apply -f network-policy.yaml
echo "✅ Application deployments created"

# Apply autoscaling for growth
kubectl apply -f autoscaling.yaml
echo "✅ Autoscaling policies created"

kubectl apply -f ingress.yaml
echo "✅ Ingress created"

# Step 4: Display deployment status
echo -e "${GREEN}Deployment completed! Showing status of Voice AI resources:${NC}"
kubectl get all -n voice-ai

# Step 5: Set up monitoring for growth
echo -e "${YELLOW}Setting up monitoring dashboard...${NC}"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

echo -e "\n${GREEN}Voice AI application is now deployed with minimal resource allocation!${NC}"
echo -e "Your application can now handle minimal traffic and will automatically scale as needed."
echo -e "Ingress IP: $(kubectl get ingress voice-ai-ingress -n voice-ai -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
echo -e "\n${YELLOW}IMPORTANT: As traffic grows, consider adjusting resources with:${NC}"
echo -e "  kubectl scale deployment/voice-agent-deployment --replicas=2 -n voice-ai"
echo -e "  kubectl scale deployment/caller-deployment --replicas=2 -n voice-ai"
