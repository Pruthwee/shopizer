#!/bin/bash
set -e
set -o pipefail

echo "=== Deploy Shopizer to AWS EKS ==="

# Project name
PROJECT_NAME="shopizer"
NAMESPACE="shopizer"
DEPLOYMENT_NAME="shopizer"
SERVICE_NAME="shopizer-service"
INGRESS_NAME="shopizer-ingress"
SECRET_NAME="shopizer-secrets"

# Ask for cluster details
read -p "Enter AWS region (e.g., us-east-1): " AWS_REGION
read -p "Enter EKS cluster name: " CLUSTER_NAME

# Ask for image URI
read -p "Enter full image URI (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com/shopizer:latest): " IMAGE_URI

# Ask for environment variables
echo ""
echo "=== Environment Variables ==="
echo "Enter values for required environment variables."
echo "Press Enter to skip (use default or existing value)."
echo ""

read -p "Enter DB_HOST (or press Enter to skip): " DB_HOST
read -p "Enter DB_PORT (or press Enter to skip): " DB_PORT
read -p "Enter DB_NAME (or press Enter to skip): " DB_NAME
read -p "Enter REDIS_HOST (or press Enter to skip): " REDIS_HOST
read -p "Enter REDIS_PORT (or press Enter to skip): " REDIS_PORT

# Ask for credentials (without echoing)
echo ""
echo "=== Credentials ==="
read -s -p "Enter DB_USER (or press Enter to skip): " DB_USER
echo ""
read -s -p "Enter DB_PASSWORD (or press Enter to skip): " DB_PASSWORD
echo ""
read -s -p "Enter REDIS_PASSWORD (or press Enter to skip): " REDIS_PASSWORD
echo ""

# Configure kubectl for EKS
echo ""
echo "=== Configuring kubectl for EKS ==="
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to configure kubectl"
    exit 1
fi

# Verify cluster connectivity
kubectl cluster-info || exit 1

# Apply namespace
echo ""
echo "=== Applying namespace ==="
kubectl apply -f kubernetes/namespace.yaml

# Create secrets
echo ""
echo "=== Creating secrets ==="
SECRET_ARGS=""
if [ -n "$DB_USER" ]; then
    SECRET_ARGS="$SECRET_ARGS --from-literal=db-user=$DB_USER"
fi
if [ -n "$DB_PASSWORD" ]; then
    SECRET_ARGS="$SECRET_ARGS --from-literal=db-password=$DB_PASSWORD"
fi
if [ -n "$REDIS_PASSWORD" ]; then
    SECRET_ARGS="$SECRET_ARGS --from-literal=redis-password=$REDIS_PASSWORD"
fi

if [ -n "$SECRET_ARGS" ]; then
    kubectl create secret generic "$SECRET_NAME" -n "$NAMESPACE" $SECRET_ARGS --dry-run=client -o yaml | kubectl apply -f -
fi

# Replace placeholders in deployment.yaml
echo ""
echo "=== Deploying application ==="
cp kubernetes/deployment.yaml kubernetes/deployment.yaml.bak

# Replace IMAGE_URI
sed -i.bak "s|{{IMAGE_URI}}|$IMAGE_URI|g" kubernetes/deployment.yaml
rm -f kubernetes/deployment.yaml.bak

# Replace DB_HOST
if [ -n "$DB_HOST" ]; then
    sed -i.bak "s|{{DB_HOST}}|$DB_HOST|g" kubernetes/deployment.yaml
    rm -f kubernetes/deployment.yaml.bak
fi

# Replace DB_PORT
if [ -n "$DB_PORT" ]; then
    sed -i.bak "s|{{DB_PORT}}|$DB_PORT|g" kubernetes/deployment.yaml
    rm -f kubernetes/deployment.yaml.bak
fi

# Replace DB_NAME
if [ -n "$DB_NAME" ]; then
    sed -i.bak "s|{{DB_NAME}}|$DB_NAME|g" kubernetes/deployment.yaml
    rm -f kubernetes/deployment.yaml.bak
fi

# Replace REDIS_HOST
if [ -n "$REDIS_HOST" ]; then
    sed -i.bak "s|{{REDIS_HOST}}|$REDIS_HOST|g" kubernetes/deployment.yaml
    rm -f kubernetes/deployment.yaml.bak
fi

# Replace REDIS_PORT
if [ -n "$REDIS_PORT" ]; then
    sed -i.bak "s|{{REDIS_PORT}}|$REDIS_PORT|g" kubernetes/deployment.yaml
    rm -f kubernetes/deployment.yaml.bak
fi

# Apply deployment
kubectl apply -f kubernetes/deployment.yaml

# Apply service
kubectl apply -f kubernetes/service.yaml

# Apply ingress
kubectl apply -f kubernetes/ingress.yaml

# Wait for rollout
echo ""
echo "=== Waiting for rollout ==="
kubectl rollout status deployment/$DEPLOYMENT_NAME -n "$NAMESPACE"

# Show resources
echo ""
echo "=== Resources ==="
kubectl get pods,svc,ingress -n "$NAMESPACE"

# Show application URL
echo ""
echo "=== Application URL ==="
echo "https://$NAMESPACE.example.com"

echo ""
echo "=== Deployment complete ==="
echo "If deployment fails, rollback with: kubectl rollout undo deployment/$DEPLOYMENT_NAME -n $NAMESPACE"
