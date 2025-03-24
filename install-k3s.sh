#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get arguments for IP and domain
PUBLIC_IP=$1
DOMAIN_NAME=$2

echo -e "${GREEN}Setting up K3s Kubernetes on DigitalOcean droplet...${NC}"
echo -e "${YELLOW}IP: ${PUBLIC_IP}${NC}"
if [ ! -z "$DOMAIN_NAME" ]; then
  echo -e "${YELLOW}Domain: ${DOMAIN_NAME}${NC}"
fi

# Install k3s with options for a single node setup
echo -e "${YELLOW}Installing k3s...${NC}"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--tls-san ${PUBLIC_IP} $([ ! -z "$DOMAIN_NAME" ] && echo "--tls-san ${DOMAIN_NAME}") --disable=traefik --write-kubeconfig-mode 644" sh -

# Wait for k3s to become available
echo -e "${YELLOW}Waiting for k3s to become available...${NC}"
until kubectl get nodes &>/dev/null; do
    echo -n "."
    sleep 3
done
echo

# Install Nginx Ingress Controller
echo -e "${YELLOW}Installing Nginx Ingress Controller...${NC}"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/cloud/deploy.yaml

# Wait for Ingress controller to be ready
echo -e "${YELLOW}Waiting for Nginx Ingress Controller to be ready...${NC}"
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s || true

# Install Cert Manager for SSL
echo -e "${YELLOW}Installing Certificate Manager...${NC}"
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.1/cert-manager.yaml

# Wait for cert-manager to be ready
echo -e "${YELLOW}Waiting for cert-manager to be ready...${NC}"
kubectl wait --namespace cert-manager \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s || true

# Create ClusterIssuer for Let's Encrypt if domain is provided
if [ ! -z "$DOMAIN_NAME" ]; then
  echo -e "${YELLOW}Setting up Let's Encrypt certificate issuer...${NC}"
  cat > /tmp/letsencrypt-issuer.yaml << EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@${DOMAIN_NAME}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

  kubectl apply -f /tmp/letsencrypt-issuer.yaml
fi

# Save configuration for later use
echo "$PUBLIC_IP" > /root/droplet_ip.txt
[ ! -z "$DOMAIN_NAME" ] && echo "$DOMAIN_NAME" > /root/domain_name.txt

echo -e "\n${GREEN}Kubernetes (k3s) installation complete!${NC}"
