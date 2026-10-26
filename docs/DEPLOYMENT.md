# Shopizer Deployment Guide

## Overview

Shopizer is a Java 11 Spring Boot e-commerce application built with Maven. This guide covers local development with Docker Compose and production deployment on AWS EKS (Elastic Kubernetes Service).

## Prerequisites

### System Requirements

- **Java**: JDK 11 (for local development)
- **Maven**: 3.8+ (for local builds)
- **Docker**: 20.10+ (for containerization)
- **AWS CLI**: 2.x (for ECR and EKS)
- **kubectl**: 1.21+ (for Kubernetes deployment)
- **eksctl**: 0.95+ (for EKS cluster management, optional)

### AWS EKS Prerequisites

- AWS account with permissions for ECR, EKS, IAM, and EC2
- IAM user/role with `AmazonEC2ContainerRegistryFullAccess`, `AmazonEKSClusterPolicy`, `AmazonEKSServicePolicy`
- An EKS cluster (create with `eksctl create cluster`)
- AWS Load Balancer Controller installed on the cluster
- EFS CSI Driver installed (for persistent file storage)
- ElastiCache for Redis (for session and cache storage)

## Local Setup with Docker Compose

### Environment Variables

Copy the example environment file and configure it:

```bash
cp .env.example .env
```

Required environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_HOST` | Database hostname | `localhost` |
| `DB_PORT` | Database port | `3306` |
| `DB_NAME` | Database name | `SALESMANAGER` |
| `DB_USER` | Database username | `shopizer` |
| `DB_PASSWORD` | Database password | - |
| `REDIS_HOST` | Redis hostname | `localhost` |
| `REDIS_PORT` | Redis port | `6379` |
| `REDIS_PASSWORD` | Redis password | - |

### Running Locally

```bash
docker-compose up
```

The application will be available at `http://localhost:8080`.

## Building and Pushing the Container Image

### Using the Build Script (Linux/macOS)

```bash
chmod +x scripts/build-push.sh
./scripts/build-push.sh
```

You will be prompted for:
1. AWS region
2. ECR registry URL
3. ECR repository name
4. Image tag (press Enter for `latest`)

### Using the Build Script (Windows)

```cmd
scripts\build-push.bat
```

### Manual Build

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <registry-url>

# Build
docker build -f Dockerfile -t <registry-url>/shopizer:latest .

# Push
docker push <registry-url>/shopizer:latest
```

## AWS EKS Deployment

### Cluster Setup

If you don't have an EKS cluster:

```bash
eksctl create cluster \
  --name shopizer \
  --region us-east-1 \
  --nodegroup-name shopizer-nodes \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 2 \
  --nodes-max 4
```

### Install AWS Load Balancer Controller

```bash
eksctl utils associate-iam-oidc-provider \
  --region us-east-1 \
  --cluster shopizer \
  --approve

helm repo add eks https://aws.github.io/eks-helm
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=shopizer \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=us-east-1 \
  --set vpcId=<vpc-id>
```

### Install EFS CSI Driver

```bash
eksctl create addon --name aws-efs-csi-driver --cluster shopizer --service-account-role-arn <irsa-arn>
```

### Deploy Application

#### Using the Deploy Script (Linux/macOS)

```bash
chmod +x scripts/deploy-image.sh
./scripts/deploy-image.sh
```

You will be prompted for:
1. AWS region
2. EKS cluster name
3. Full image URI (from build-push.sh)
4. Environment variables (DB_HOST, DB_PORT, DB_NAME, REDIS_HOST, REDIS_PORT)
5. Credentials (DB_USER, DB_PASSWORD, REDIS_PASSWORD)

#### Using the Deploy Script (Windows)

```cmd
scripts\deploy-image.bat
```

#### Manual Deployment

```bash
# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name shopizer

# Create namespace
kubectl apply -f kubernetes/namespace.yaml

# Create secrets
kubectl create secret generic shopizer-secrets \
  -n shopizer \
  --from-literal=db-user=shopizer \
  --from-literal=db-password=<password> \
  --from-literal=redis-password=<password> \
  --dry-run=client -o yaml | kubectl apply -f -

# Deploy
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/ingress.yaml

# Check status
kubectl rollout status deployment/shopizer -n shopizer
```

### Verify Deployment

```bash
# Check pods
kubectl get pods -n shopizer

# Check service
kubectl get svc -n shopizer

# Check ingress
kubectl get ingress -n shopizer

# Check health
kubectl exec -it <pod-name> -n shopizer -- curl http://localhost:8080/actuator/health
```

## Configuration Management

### Environment Variables

The application reads configuration from environment variables:

| Variable | Description |
|----------|-------------|
| `DB_HOST` | Database hostname |
| `DB_PORT` | Database port |
| `DB_NAME` | Database name |
| `DB_USER` | Database username (from Kubernetes Secret) |
| `DB_PASSWORD` | Database password (from Kubernetes Secret) |
| `REDIS_HOST` | Redis hostname |
| `REDIS_PORT` | Redis port |
| `REDIS_PASSWORD` | Redis password (from Kubernetes Secret) |
| `SPRING_PROFILES_ACTIVE` | Spring profile (default: `prod`) |
| `JAVA_OPTS` | JVM options |

### Kubernetes Secrets

Sensitive values (database credentials, Redis password) are stored in a Kubernetes Secret named `shopizer-secrets` in the `shopizer` namespace.

### Kubernetes ConfigMaps

Non-sensitive configuration (hostnames, ports) can be stored in a ConfigMap and injected as environment variables.

## Security Considerations

1. **Secrets Management**: Database credentials and Redis passwords are stored in Kubernetes Secrets, never in plain text in manifests.
2. **Non-root User**: The container runs as a non-root user for security.
3. **TLS**: Enable TLS for database connections and Redis in production.
4. **Network Policies**: Apply Kubernetes NetworkPolicies to restrict traffic between services.
5. **Resource Limits**: CPU and memory limits are set to prevent resource exhaustion.
6. **Image Scanning**: Scan container images for vulnerabilities before pushing to ECR.

## Java Notes

### JVM Settings

The application runs with the following JVM settings optimized for containerized environments:

```
-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0
```

- `-Xmx512m`: Maximum heap size of 512MB
- `-Xms256m`: Initial heap size of 256MB
- `-XX:+UseContainerSupport`: Enables container-aware memory management (default in JDK 10+)
- `-XX:MaxRAMPercentage=75.0`: Heap can use up to 75% of container memory limit

### Spring Profiles

The application uses the `prod` Spring profile by default (`SPRING_PROFILES_ACTIVE=prod`). This profile enables production-optimized settings.

### Health Endpoints

The application exposes Spring Boot Actuator health endpoints:

- `/actuator/health` - General health check
- `/actuator/health/liveness` - Liveness probe (Kubernetes)
- `/actuator/health/readiness` - Readiness probe (Kubernetes)

These endpoints are used by Kubernetes liveness and readiness probes.

### Build Details

- **Java Version**: 11
- **Build Tool**: Maven 3.9.4
- **Base Image**: eclipse-temurin:11-jdk
- **Framework**: Spring Boot 2.5.12
- **Packaging**: JAR (runnable with `java -jar`)

## Troubleshooting

### Pod Failures

```bash
# Check pod logs
kubectl logs <pod-name> -n shopizer

# Describe pod for events
kubectl describe pod <pod-name> -n shopizer

# Check pod status
kubectl get pods -n shopizer -o wide
```

### Service Issues

```bash
# Check service endpoints
kubectl get endpoints -n shopizer

# Describe service
kubectl describe svc shopizer-service -n shopizer
```

### Ingress Problems

```bash
# Check ingress status
kubectl get ingress -n shopizer

# Describe ingress
kubectl describe ingress shopizer-ingress -n shopizer
```

### Scaling

```bash
# Scale deployment
kubectl scale deployment shopizer --replicas=3 -n shopizer

# Create HPA
kubectl autoscale deployment shopizer --cpu-percent=70 --min=2 --max=10 -n shopizer
```

### Rollback

```bash
# Rollback to previous revision
kubectl rollout undo deployment/shopizer -n shopizer

# Rollback to specific revision
kubectl rollout undo deployment/shopizer --to-revision=2 -n shopizer
```
