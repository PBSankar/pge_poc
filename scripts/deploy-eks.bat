@echo off
setlocal EnableDelayedExpansion

echo === CRM Application EKS Deployment Script ===
echo.

REM Check required tools
echo [INFO] Checking dependencies...
kubectl version --client >nul 2>&1
if errorlevel 1 (
    echo [ERROR] kubectl is not installed. Please install it first.
    exit /b 1
)

aws --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] AWS CLI is not installed. Please install it first.
    exit /b 1
)

echo [INFO] All required dependencies are installed.
echo.

REM Get EKS cluster information
echo EKS Cluster Configuration:
set /p AWS_REGION=Enter AWS Region (e.g., us-east-1): 
set /p CLUSTER_NAME=Enter EKS Cluster Name: 
set /p DOCKER_IMAGE=Enter Docker Image (with tag, e.g., your-registry/crm-app:latest): 
echo.

REM Update kubeconfig
echo [INFO] Updating kubeconfig for EKS cluster...
aws eks update-kubeconfig --region %AWS_REGION% --name %CLUSTER_NAME%
if errorlevel 1 (
    echo [ERROR] Failed to update kubeconfig. Check your AWS credentials and cluster name.
    exit /b 1
)
echo [INFO] Kubeconfig updated successfully.
echo.

REM Verify cluster connection
echo [INFO] Verifying cluster connection...
kubectl cluster-info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Cannot connect to cluster. Please check your configuration.
    exit /b 1
)
echo [INFO] Successfully connected to cluster.
kubectl get nodes
echo.

REM Update deployment image
echo [INFO] Updating deployment image to: %DOCKER_IMAGE%

REM Create a temporary deployment file with the updated image
copy kubernetes\deployment.yaml kubernetes\deployment-temp.yaml >nul

REM Replace the image in the deployment file (Windows equivalent)
powershell -Command "(Get-Content kubernetes\deployment-temp.yaml) -replace 'image: crm-app:latest', 'image: %DOCKER_IMAGE%' | Set-Content kubernetes\deployment-temp.yaml"

echo [INFO] Deployment file updated with new image.
echo.

REM Apply Kubernetes manifests
echo [INFO] Applying Kubernetes manifests...

REM Apply manifests in order
set MANIFESTS=kubernetes\namespace.yaml kubernetes\configmap.yaml kubernetes\secret.yaml kubernetes\deployment-temp.yaml kubernetes\service.yaml kubernetes\ingress.yaml

for %%f in (%MANIFESTS%) do (
    if exist "%%f" (
        echo [INFO] Applying %%f...
        kubectl apply -f "%%f"
        if errorlevel 1 (
            echo [ERROR] Failed to apply %%f
            exit /b 1
        )
        echo [INFO] Successfully applied %%f
    ) else (
        echo [WARNING] Manifest file %%f not found, skipping...
    )
)

REM Clean up temporary file
if exist kubernetes\deployment-temp.yaml del kubernetes\deployment-temp.yaml
echo.

REM Wait for deployment
echo [INFO] Waiting for deployment to be ready...
kubectl wait --for=condition=available --timeout=300s deployment/crm-app-deployment -n crm-app
if errorlevel 1 (
    echo [ERROR] Deployment failed to become ready within 5 minutes.
    echo [INFO] Checking deployment status...
    kubectl get pods -n crm-app
    kubectl describe deployment crm-app-deployment -n crm-app
    exit /b 1
)
echo [INFO] Deployment is ready!
echo.

REM Get deployment status
echo [INFO] Deployment Status:
kubectl get all -n crm-app
echo.

echo [INFO] Pod Details:
kubectl get pods -n crm-app -o wide
echo.

echo [INFO] Service Details:
kubectl get svc -n crm-app
echo.

echo [INFO] Ingress Details:
kubectl get ingress -n crm-app
echo.

REM Get application URL
echo [INFO] Getting application URL...

REM Try to get LoadBalancer service external IP
for /f "delims=" %%i in ('kubectl get svc crm-app-service -n crm-app -o jsonpath="{.status.loadBalancer.ingress[0].hostname}" 2^>nul') do set EXTERNAL_IP=%%i

if not "%EXTERNAL_IP%"=="" (
    echo Application URL: http://!EXTERNAL_IP!
    echo Health Check: http://!EXTERNAL_IP!/appinfo/health
) else (
    REM Get ingress URL if available
    for /f "delims=" %%i in ('kubectl get ingress crm-app-ingress -n crm-app -o jsonpath="{.spec.rules[0].host}" 2^>nul') do set INGRESS_HOST=%%i
    
    if not "!INGRESS_HOST!"=="" (
        echo Application URL: https://!INGRESS_HOST!
        echo Health Check: https://!INGRESS_HOST!/appinfo/health
    ) else (
        echo [WARNING] External URL not available yet. Use port-forward for testing:
        echo kubectl port-forward svc/crm-app-service 8080:80 -n crm-app
        echo Then access: http://localhost:8080
    )
)
echo.

REM Check deployment status and offer rollback
for /f "delims=" %%i in ('kubectl get deployment crm-app-deployment -n crm-app -o jsonpath="{.status.conditions[?(@.type==\"Available\")].status}" 2^>nul') do set DEPLOYMENT_STATUS=%%i

if "%DEPLOYMENT_STATUS%"=="False" (
    echo [ERROR] Deployment is not fully available.
    set /p ROLLBACK_CHOICE=Do you want to rollback the deployment? (y/n): 
    if /i "!ROLLBACK_CHOICE!"=="y" (
        echo [INFO] Rolling back deployment...
        kubectl rollout undo deployment/crm-app-deployment -n crm-app
        kubectl rollout status deployment/crm-app-deployment -n crm-app
        echo [INFO] Rollback completed.
    )
)

echo.
echo [INFO] Deployment completed!
echo.
echo [INFO] For logs, use: kubectl logs -f deployment/crm-app-deployment -n crm-app
echo [INFO] For shell access, use: kubectl exec -it deployment/crm-app-deployment -n crm-app -- /bin/bash
echo.
pause