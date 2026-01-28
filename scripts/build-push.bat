@echo off
setlocal EnableDelayedExpansion

echo === CRM Application Docker Build and Push Script ===
echo.

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker is not running. Please start Docker and try again.
    exit /b 1
)

REM Get application name and version
set APP_NAME=crm-app
for /f "tokens=1-4 delims=/. " %%a in ('date /t') do set DATE=%%c%%a%%b
for /f "tokens=1-2 delims=:" %%a in ('time /t') do set TIME=%%a%%b
set TIME=!TIME: =0!
set VERSION=%DATE%-%TIME%
echo Application: %APP_NAME%
echo Version: %VERSION%
echo.

REM Registry selection
echo Select container registry:
echo 1) AWS ECR
echo 2) Docker Hub
echo 3) Other Registry
set /p REGISTRY_CHOICE=Enter your choice (1-3): 

if "%REGISTRY_CHOICE%"=="1" (
    echo.
    echo [INFO] Setting up AWS ECR...
    set /p AWS_REGION=Enter AWS Region (e.g., us-east-1): 
    set /p AWS_ACCOUNT_ID=Enter AWS Account ID: 
    set /p ECR_REPO=Enter ECR Repository name (default: crm-app): 
    if "!ECR_REPO!"=="" set ECR_REPO=crm-app
    
    set REGISTRY_URL=!AWS_ACCOUNT_ID!.dkr.ecr.!AWS_REGION!.amazonaws.com
    set IMAGE_NAME=!REGISTRY_URL!/!ECR_REPO!
    
    REM AWS CLI check
    aws --version >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] AWS CLI is not installed. Please install it first.
        exit /b 1
    )
    
    REM Create ECR repository if it doesn't exist
    echo [INFO] Creating ECR repository if it doesn't exist...
    aws ecr describe-repositories --region !AWS_REGION! --repository-names !ECR_REPO! >nul 2>&1
    if errorlevel 1 (
        aws ecr create-repository --region !AWS_REGION! --repository-name !ECR_REPO!
    )
    
    REM Login to ECR
    echo [INFO] Logging into AWS ECR...
    for /f "delims=" %%i in ('aws ecr get-login-password --region !AWS_REGION!') do docker login --username AWS --password-stdin !REGISTRY_URL! < echo %%i
    
) else if "%REGISTRY_CHOICE%"=="2" (
    echo.
    echo [INFO] Setting up Docker Hub...
    set /p DOCKER_USERNAME=Enter Docker Hub username: 
    set /p DOCKER_PASSWORD=Enter Docker Hub password/token: 
    
    set IMAGE_NAME=!DOCKER_USERNAME!/!APP_NAME!
    
    REM Login to Docker Hub
    echo [INFO] Logging into Docker Hub...
    echo !DOCKER_PASSWORD! | docker login --username !DOCKER_USERNAME! --password-stdin
    
) else if "%REGISTRY_CHOICE%"=="3" (
    echo.
    echo [INFO] Setting up custom registry...
    set /p CUSTOM_REGISTRY=Enter registry URL (e.g., registry.example.com): 
    set /p REGISTRY_USERNAME=Enter username: 
    set /p REGISTRY_PASSWORD=Enter password: 
    
    set IMAGE_NAME=!CUSTOM_REGISTRY!/!APP_NAME!
    
    REM Login to custom registry
    echo [INFO] Logging into custom registry...
    echo !REGISTRY_PASSWORD! | docker login --username !REGISTRY_USERNAME! --password-stdin !CUSTOM_REGISTRY!
    
) else (
    echo [ERROR] Invalid choice. Exiting.
    exit /b 1
)

echo.
echo [INFO] Building Docker image...
echo Image: !IMAGE_NAME!:!VERSION!
echo Image: !IMAGE_NAME!:latest

REM Build the Docker image
docker build -t "!IMAGE_NAME!:!VERSION!" -t "!IMAGE_NAME!:latest" .
if errorlevel 1 (
    echo [ERROR] Docker build failed!
    exit /b 1
)
echo [INFO] Docker image built successfully!

echo.
echo [INFO] Pushing Docker images...

REM Push versioned image
docker push "!IMAGE_NAME!:!VERSION!"
if errorlevel 1 (
    echo [ERROR] Failed to push !IMAGE_NAME!:!VERSION!
    exit /b 1
)
echo [INFO] Pushed !IMAGE_NAME!:!VERSION!

REM Push latest image
docker push "!IMAGE_NAME!:latest"
if errorlevel 1 (
    echo [ERROR] Failed to push !IMAGE_NAME!:latest!
    exit /b 1
)
echo [INFO] Pushed !IMAGE_NAME!:latest

echo.
echo [INFO] Build and push completed successfully!
echo Images pushed:
echo   - !IMAGE_NAME!:!VERSION!
echo   - !IMAGE_NAME!:latest
echo.
echo [WARNING] Remember to update your Kubernetes deployment files with the new image:
echo   !IMAGE_NAME!:!VERSION!
echo.
pause