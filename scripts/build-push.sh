#!/bin/bash
set -e

echo "=== Build and Push Script for Shopizer ==="

# Project name
PROJECT_NAME="shopizer"

# Sanitize image name
IMAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')

# Ask for registry details
read -p "Enter AWS region (e.g., us-east-1): " AWS_REGION
read -p "Enter ECR registry URL (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com): " REGISTRY_URL
read -p "Enter ECR repository name: " ECR_REPO
read -p "Enter image tag (press Enter for latest): " IMAGE_TAG

# Sanitize tag
if [ -z "$IMAGE_TAG" ]; then
    IMAGE_TAG="latest"
fi

# Build full image name
FULL_IMAGE_NAME="$REGISTRY_URL/$ECR_REPO:$IMAGE_TAG"

echo ""
echo "=== Configuration ==="
echo "Project: $PROJECT_NAME"
echo "Image: $FULL_IMAGE_NAME"
echo "Platform: linux/amd64"
echo ""

# Login to ECR
echo "=== Logging in to AWS ECR ==="
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY_URL"
if [ $? -ne 0 ]; then
    echo "ERROR: ECR login failed"
    exit 1
fi

# Create repository if it doesn't exist
echo "=== Checking ECR repository ==="
aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$AWS_REGION" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Creating ECR repository: $ECR_REPO"
    aws ecr create-repository --repository-name "$ECR_REPO" --region "$AWS_REGION"
fi

# Build the image
echo ""
echo "=== Building Docker image ==="
docker build -f Dockerfile -t "$FULL_IMAGE_NAME" .
if [ $? -ne 0 ]; then
    echo "ERROR: Docker build failed"
    exit 1
fi

# Push the image
echo ""
echo "=== Pushing Docker image ==="
docker push "$FULL_IMAGE_NAME"
if [ $? -ne 0 ]; then
    echo "ERROR: Docker push failed"
    exit 1
fi

echo ""
echo "=== Success ==="
echo "Image pushed to: $FULL_IMAGE_NAME"
