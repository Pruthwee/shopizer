@echo off
setlocal enabledelayedexpansion

echo === Deploy Shopizer to AWS EKS ===

set PROJECT_NAME=shopizer
set NAMESPACE=shopizer
set DEPLOYMENT_NAME=shopizer
set SERVICE_NAME=shopizer-service
set INGRESS_NAME=shopizer-ingress
set SECRET_NAME=shopizer-secrets

set /p AWS_REGION="Enter AWS region (e.g., us-east-1): "
set /p CLUSTER_NAME="Enter EKS cluster name: "
set /p IMAGE_URI="Enter full image URI (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com/shopizer:latest): "

echo.
echo === Environment Variables ===
echo Enter values for required environment variables.
echo Press Enter to skip (use default or existing value).
echo.

set /p DB_HOST="Enter DB_HOST (or press Enter to skip): "
set /p DB_PORT="Enter DB_PORT (or press Enter to skip): "
set /p DB_NAME="Enter DB_NAME (or press Enter to skip): "
set /p REDIS_HOST="Enter REDIS_HOST (or press Enter to skip): "
set /p REDIS_PORT="Enter REDIS_PORT (or press Enter to skip): "

echo.
echo === Credentials ===
set /p DB_USER="Enter DB_USER (or press Enter to skip): "
set /p DB_PASSWORD="Enter DB_PASSWORD (or press Enter to skip): "
set /p REDIS_PASSWORD="Enter REDIS_PASSWORD (or press Enter to skip): "

echo.
echo === Configuring kubectl for EKS ===
aws eks update-kubeconfig --region !AWS_REGION! --name !CLUSTER_NAME!
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to configure kubectl
    exit /b 1
)

kubectl cluster-info
if !ERRORLEVEL! neq 0 (
    echo ERROR: Cluster connectivity check failed
    exit /b 1
)

echo.
echo === Applying namespace ===
kubectl apply -f kubernetes/namespace.yaml
if !ERRORLEVEL! neq 0 (
    echo ERROR: Namespace creation failed
    exit /b 1
)

echo.
echo === Creating secrets ===
set SECRET_ARGS=
if not "!DB_USER!"=="" (
    set SECRET_ARGS=!SECRET_ARGS! --from-literal=db-user=!DB_USER!
)
if not "!DB_PASSWORD!"=="" (
    set SECRET_ARGS=!SECRET_ARGS! --from-literal=db-password=!DB_PASSWORD!
)
if not "!REDIS_PASSWORD!"=="" (
    set SECRET_ARGS=!SECRET_ARGS! --from-literal=redis-password=!REDIS_PASSWORD!
)

if not "!SECRET_ARGS!"=="" (
    kubectl create secret generic !SECRET_NAME! -n !NAMESPACE! !SECRET_ARGS! --dry-run=client -o yaml | kubectl apply -f -
    if !ERRORLEVEL! neq 0 (
        echo ERROR: Secret creation failed
        exit /b 1
    )
)

echo.
echo === Deploying application ===
copy kubernetes\deployment.yaml kubernetes\deployment.yaml.bak >nul 2>&1

REM Replace IMAGE_URI
powershell -Command "(gc kubernetes\deployment.yaml) -replace '{{IMAGE_URI}}', '!IMAGE_URI!' | Out-File -encoding ASCII kubernetes\deployment.yaml"

REM Replace DB_HOST
if not "!DB_HOST!"=="" (
    powershell -Command "(gc kubernetes\deployment.yaml) -replace '{{DB_HOST}}', '!DB_HOST!' | Out-File -encoding ASCII kubernetes\deployment.yaml"
)

REM Replace DB_PORT
if not "!DB_PORT!"=="" (
    powershell -Command "(gc kubernetes\deployment.yaml) -replace '{{DB_PORT}}', '!DB_PORT!' | Out-File -encoding ASCII kubernetes\deployment.yaml"
)

REM Replace DB_NAME
if not "!DB_NAME!"=="" (
    powershell -Command "(gc kubernetes\deployment.yaml) -replace '{{DB_NAME}}', '!DB_NAME!' | Out-File -encoding ASCII kubernetes\deployment.yaml"
)

REM Replace REDIS_HOST
if not "!REDIS_HOST!"=="" (
    powershell -Command "(gc kubernetes\deployment.yaml) -replace '{{REDIS_HOST}}', '!REDIS_HOST!' | Out-File -encoding ASCII kubernetes\deployment.yaml"
)

REM Replace REDIS_PORT
if not "!REDIS_PORT!"=="" (
    powershell -Command "(gc kubernetes\deployment.yaml) -replace '{{REDIS_PORT}}', '!REDIS_PORT!' | Out-File -encoding ASCII kubernetes\deployment.yaml"
)

del kubernetes\deployment.yaml.bak >nul 2>&1

kubectl apply -f kubernetes\deployment.yaml
if !ERRORLEVEL! neq 0 (
    echo ERROR: Deployment failed
    exit /b 1
)

kubectl apply -f kubernetes\service.yaml
if !ERRORLEVEL! neq 0 (
    echo ERROR: Service creation failed
    exit /b 1
)

kubectl apply -f kubernetes\ingress.yaml
if !ERRORLEVEL! neq 0 (
    echo ERROR: Ingress creation failed
    exit /b 1
)

echo.
echo === Waiting for rollout ===
kubectl rollout status deployment\!DEPLOYMENT_NAME! -n !NAMESPACE!
if !ERRORLEVEL! neq 0 (
    echo ERROR: Rollout failed
    echo Rollback with: kubectl rollout undo deployment\!DEPLOYMENT_NAME! -n !NAMESPACE!
    exit /b 1
)

echo.
echo === Resources ===
kubectl get pods,svc,ingress -n !NAMESPACE!

echo.
echo === Application URL ===
echo https://!NAMESPACE!.example.com

echo.
echo === Deployment complete ===
echo If deployment fails, rollback with: kubectl rollout undo deployment\!DEPLOYMENT_NAME! -n !NAMESPACE!
