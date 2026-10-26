@echo off
setlocal enabledelayedexpansion

echo === Build and Push Script for Shopizer ===

set PROJECT_NAME=shopizer

REM Sanitize image name using PowerShell
for /f %%i in ('powershell -command "$p = '%PROJECT_NAME%' -replace '[^a-z0-9]', '-'; $p.Trim('-')"') do set IMAGE_NAME=%%i

set /p AWS_REGION="Enter AWS region (e.g., us-east-1): "
set /p REGISTRY_URL="Enter ECR registry URL (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com): "
set /p ECR_REPO="Enter ECR repository name: "
set /p IMAGE_TAG="Enter image tag (press Enter for latest): "

if "!IMAGE_TAG!"=="" (
    set IMAGE_TAG=latest
)

set FULL_IMAGE_NAME=!REGISTRY_URL!/!ECR_REPO!:!IMAGE_TAG!

echo.
echo === Configuration ===
echo Project: !PROJECT_NAME!
echo Image: !FULL_IMAGE_NAME!
echo Platform: linux/amd64
echo.

echo === Logging in to AWS ECR ===
aws ecr get-login-password --region !AWS_REGION! | docker login --username AWS --password-stdin !REGISTRY_URL!
if !ERRORLEVEL! neq 0 (
    echo ECR login failed
    exit /b 1
)

echo === Checking ECR repository ===
aws ecr describe-repositories --repository-names !ECR_REPO! --region !AWS_REGION! >nul 2>&1
if !ERRORLEVEL! neq 0 (
    echo Creating ECR repository: !ECR_REPO!
    aws ecr create-repository --repository-name !ECR_REPO! --region !AWS_REGION!
)

echo.
echo === Building Docker image ===
docker build -f Dockerfile -t !FULL_IMAGE_NAME! .
if !ERRORLEVEL! neq 0 (
    echo Docker build failed
    exit /b 1
)

echo.
echo === Pushing Docker image ===
docker push !FULL_IMAGE_NAME!
if !ERRORLEVEL! neq 0 (
    echo Docker push failed
    exit /b 1
)

echo.
echo === Success ===
echo Image pushed to: !FULL_IMAGE_NAME!
