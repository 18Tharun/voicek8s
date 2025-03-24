#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Deploying Voice AI application to Kubernetes...${NC}"

# Check kubectl connectivity
if ! kubectl cluster-info &>/dev/null; then
  echo -e "${RED}Error: Unable to connect to Kubernetes cluster${NC}"
  echo -e "Please ensure your kubectl is properly configured"
  exit 1
fi

# Create namespace
echo -e "${YELLOW}Creating namespace...${NC}"
kubectl apply -f kubernetes/namespace.yaml

# Create network policy (equivalent to livekit-network in Docker)
echo -e "${YELLOW}Setting up network policy...${NC}"
kubectl apply -f kubernetes/network-policy.yaml

# Create ConfigMap and Secrets
echo -e "${YELLOW}Creating ConfigMap and Secrets...${NC}"
kubectl apply -f kubernetes/configmap.yaml
kubectl apply -f kubernetes/secrets.yaml

# Create database deployment
echo -e "${YELLOW}Deploying database (abhishekanbu01/db5)...${NC}"
kubectl apply -f kubernetes/database-deployment.yaml

# Wait for database to be ready
echo -e "${YELLOW}Waiting for database to be ready...${NC}"
kubectl wait --namespace voice-ai --for=condition=ready pod --selector=app=db --timeout=120s

# Deploy frontend and backend services
echo -e "${YELLOW}Deploying frontend (abhishekanbu01/frontend2)...${NC}"
kubectl apply -f kubernetes/frontend-deployment.yaml

echo -e "${YELLOW}Deploying parallel and voice-agent services...${NC}"
kubectl apply -f kubernetes/backend-services.yaml

# Setup autoscaling
echo -e "${YELLOW}Configuring autoscaling...${NC}"
kubectl apply -f kubernetes/autoscaling.yaml

# Setup ingress
echo -e "${YELLOW}Configuring ingress...${NC}"
kubectl apply -f kubernetes/ingress.yaml

echo -e "${GREEN}Deployment complete!${NC}"
echo -e "${YELLOW}Getting pod status:${NC}"
kubectl get pods -n voice-ai

echo -e "${YELLOW}Getting services:${NC}"
kubectl get svc -n voice-ai

echo -e "${GREEN}Your application should be accessible shortly.${NC}"
