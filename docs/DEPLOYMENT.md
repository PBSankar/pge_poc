# CRM Application Deployment Guide

## Overview

This guide provides comprehensive instructions for deploying the CRM Spring Boot application using Docker and Kubernetes. The application is a Java 8 based Spring Boot 1.5.10 web application with JPA, Security, and Actuator features.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Local Development](#local-development)
- [Docker Deployment](#docker-deployment)
- [Kubernetes Deployment](#kubernetes-deployment)
- [AWS EKS Deployment](#aws-eks-deployment)
- [Configuration Management](#configuration-management)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)

## Prerequisites

### Required Tools

- **Docker**: Version 20.10 or higher
- **Docker Compose**: Version 1.29 or higher
- **Kubectl**: Compatible with your Kubernetes cluster version
- **AWS CLI**: Version 2.x (for EKS deployment)
- **Java 8**: For local development
- **Maven**: Version 3.6 or higher

### Required Access

- Docker registry access (Docker Hub, AWS ECR, or private registry)
- Kubernetes cluster access with appropriate RBAC permissions
- AWS account with EKS access (for EKS deployment)

## Project Structure

```
.
├── Dockerfile                 # Multi-stage Docker build file
├── docker-compose.yml         # Local Docker Compose setup
├── .dockerignore              # Docker build exclusions
├── scripts/
│   ├── build-push.sh          # Linux build and push script
│   ├── build-push.bat         # Windows build and push script
│   ├── deploy-eks.sh          # Linux EKS deployment script
│   └── deploy-eks.bat         # Windows EKS deployment script
├── kubernetes/
│   ├── namespace.yaml         # Kubernetes namespace
│   ├── configmap.yaml         # Application configuration
│   ├── secret.yaml            # Database credentials
│   ├── deployment.yaml        # Application deployment
│   ├── service.yaml           # Kubernetes service
│   └── ingress.yaml           # Ingress configuration
├── docs/
│   └── DEPLOYMENT.md          # This deployment guide
└── CRM-master/                # Application source code
    ├── pom.xml
    └── src/
```

## Local Development

### Building the Application

1. **Clone and navigate to the project:**
   ```bash
   cd /path/to/crm-application
   ```

2. **Build with Maven:**
   ```bash
   cd CRM-master
   mvn clean package -DskipTests
   ```

3. **Run locally:**
   ```bash
   java -jar target/CRM-0.0.1-SNAPSHOT.jar
   ```

4. **Access the application:**
   - Main application: http://localhost:8080
   - Health check: http://localhost:8080/appinfo/health
   - Application info: http://localhost:8080/appinfo/info

### Database Setup

The application supports both H2 (development) and MySQL (production) databases:

**H2 Database (Default for development):**
- No additional setup required
- Data is stored in memory or local file

**MySQL Database:**
- Install MySQL 5.7+ or MariaDB 10.3+
- Create database: `CREATE DATABASE crm;`
- Update connection properties in `application.properties`

## Docker Deployment

### Building Docker Image

1. **Build using Docker:**
   ```bash
   docker build -t crm-app:latest .
   ```

2. **Run with Docker:**
   ```bash
   docker run -p 8080:8080 -e SPRING_PROFILES_ACTIVE=docker crm-app:latest
   ```

### Using Docker Compose

1. **Start the application:**
   ```bash
   docker-compose up -d
   ```

2. **View logs:**
   ```bash
   docker-compose logs -f crm-app
   ```

3. **Stop the application:**
   ```bash
   docker-compose down
   ```

### Build and Push Scripts

#### Linux/macOS:
```bash
# Make script executable
chmod +x scripts/build-push.sh

# Run the script
./scripts/build-push.sh
```

#### Windows:
```cmd
# Run the batch script
scripts\build-push.bat
```

The scripts will:
- Prompt for registry selection (AWS ECR, Docker Hub, or custom)
- Build the Docker image with proper tags
- Authenticate to the selected registry
- Push both versioned and latest tags

## Kubernetes Deployment

### Prerequisites

1. **Kubernetes cluster** (1.19+ recommended)
2. **NGINX Ingress Controller** (for ingress)
3. **cert-manager** (for TLS certificates)
4. **External database** (MySQL/MariaDB)

### Manual Deployment

1. **Create namespace:**
   ```bash
   kubectl apply -f kubernetes/namespace.yaml
   ```

2. **Update secrets:**
   ```bash
   # Create database secret with actual credentials
   kubectl create secret generic crm-db-secret \
     --from-literal=username=your_db_username \
     --from-literal=password=your_db_password \
     --namespace=crm-app
   ```

3. **Apply configuration:**
   ```bash
   kubectl apply -f kubernetes/configmap.yaml
   ```

4. **Deploy application:**
   ```bash
   kubectl apply -f kubernetes/deployment.yaml
   kubectl apply -f kubernetes/service.yaml
   kubectl apply -f kubernetes/ingress.yaml
   ```

5. **Verify deployment:**
   ```bash
   kubectl get all -n crm-app
   kubectl logs -f deployment/crm-app-deployment -n crm-app
   ```

### Using Deployment Scripts

#### Linux/macOS:
```bash
chmod +x scripts/deploy-eks.sh
./scripts/deploy-eks.sh
```

#### Windows:
```cmd
scripts\deploy-eks.bat
```

## AWS EKS Deployment

### Prerequisites

1. **AWS Account** with EKS permissions
2. **EKS Cluster** already created
3. **AWS CLI** configured with appropriate credentials
4. **kubectl** configured for EKS

### EKS Setup

1. **Create EKS cluster** (if not exists):
   ```bash
   # Using eksctl
   eksctl create cluster --name crm-cluster --region us-east-1 --nodes 2
   ```

2. **Update kubeconfig:**
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name crm-cluster
   ```

3. **Install NGINX Ingress Controller:**
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/aws/deploy.yaml
   ```

### Deployment Process

The deployment scripts will:
1. Verify AWS and kubectl connectivity
2. Update kubeconfig for the specified cluster
3. Apply all Kubernetes manifests in the correct order
4. Wait for deployment to become ready
5. Display deployment status and access URLs

### RDS Database Integration

For production deployments, use AWS RDS:

1. **Create RDS instance:**
   ```bash
   aws rds create-db-instance \
     --db-instance-identifier crm-database \
     --db-instance-class db.t3.micro \
     --engine mysql \
     --master-username admin \
     --master-user-password your-secure-password \
     --allocated-storage 20
   ```

2. **Update ConfigMap** with RDS endpoint:
   ```yaml
   spring.datasource.url=jdbc:mysql://crm-database.cluster-xyz.region.rds.amazonaws.com:3306/crm
   ```

## Configuration Management

### Environment Variables

The application uses the following key environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `SPRING_PROFILES_ACTIVE` | `default` | Active Spring profile |
| `DB_HOST` | `localhost` | Database hostname |
| `DB_PORT` | `3306` | Database port |
| `DB_NAME` | `crm` | Database name |
| `DB_USERNAME` | `root` | Database username |
| `DB_PASSWORD` | `password` | Database password |
| `JAVA_OPTS` | See Dockerfile | JVM options |

### Configuration Files

1. **application.properties** - Main configuration
2. **ConfigMap** - Kubernetes configuration
3. **Secret** - Sensitive data (database credentials)

### Profiles

- **default**: Local development with H2
- **docker**: Docker container with external MySQL
- **kubernetes**: Kubernetes deployment configuration

## Troubleshooting

### Common Issues

#### 1. Application Won't Start

**Symptoms:** Container exits immediately or crashes

**Solutions:**
```bash
# Check logs
docker logs <container-id>
kubectl logs -f deployment/crm-app-deployment -n crm-app

# Common fixes:
# - Verify Java version compatibility
# - Check database connectivity
# - Validate environment variables
# - Ensure sufficient memory allocation
```

#### 2. Database Connection Issues

**Symptoms:** "Connection refused" or "Access denied" errors

**Solutions:**
```bash
# Test database connectivity
telnet $DB_HOST $DB_PORT

# Verify credentials
kubectl get secret crm-db-secret -n crm-app -o yaml

# Check network policies
kubectl get networkpolicies -n crm-app
```

#### 3. Health Check Failures

**Symptoms:** Pod restarts, readiness probe failures

**Solutions:**
```bash
# Test health endpoint manually
curl http://pod-ip:8080/appinfo/health

# Adjust probe timeouts in deployment.yaml
initialDelaySeconds: 60  # Increase if app takes long to start
timeoutSeconds: 10       # Increase for slow responses
```

#### 4. Image Pull Issues

**Symptoms:** "ImagePullBackOff" or "ErrImagePull"

**Solutions:**
```bash
# Verify image exists
docker pull your-registry/crm-app:tag

# Check image pull secrets
kubectl get secrets -n crm-app

# For private registries, create pull secret:
kubectl create secret docker-registry regcred \
  --docker-server=your-registry \
  --docker-username=username \
  --docker-password=password \
  --namespace=crm-app
```

### Debugging Commands

```bash
# Get pod shell access
kubectl exec -it deployment/crm-app-deployment -n crm-app -- /bin/bash

# View application logs
kubectl logs -f deployment/crm-app-deployment -n crm-app

# Describe resources for events
kubectl describe pod <pod-name> -n crm-app
kubectl describe deployment crm-app-deployment -n crm-app

# Port forward for local testing
kubectl port-forward svc/crm-app-service 8080:80 -n crm-app
```

### Performance Tuning

#### JVM Settings
```bash
# For production workloads, adjust in deployment.yaml:
JAVA_OPTS: "-Xmx1g -Xms512m -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
```

#### Resource Limits
```yaml
# Adjust based on actual usage:
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

## Security Considerations

### Container Security

1. **Non-root user**: Application runs as non-root user
2. **Minimal base image**: Uses slim/distroless images when possible
3. **Security scanning**: Regularly scan images for vulnerabilities

### Kubernetes Security

1. **Network Policies**: Implement network segmentation
2. **RBAC**: Use least-privilege access controls
3. **Pod Security Standards**: Apply appropriate security contexts
4. **Secrets Management**: Use Kubernetes secrets or external secret managers

### Database Security

1. **Encryption**: Enable encryption in transit and at rest
2. **Access Controls**: Use database-specific authentication
3. **Network Isolation**: Place database in private subnets
4. **Backup Encryption**: Encrypt database backups

### TLS/SSL Configuration

1. **Ingress TLS**: Configure TLS termination at ingress
2. **Certificate Management**: Use cert-manager for automatic certificate renewal
3. **Internal TLS**: Consider service mesh for internal TLS

## Monitoring and Observability

### Health Checks

- **Liveness**: `/appinfo/health` - Restarts unhealthy pods
- **Readiness**: `/appinfo/health` - Controls traffic routing
- **Startup**: Custom probe for slow-starting applications

### Logging

1. **Application Logs**: Structured logging with proper levels
2. **Centralized Logging**: Use ELK stack or AWS CloudWatch
3. **Log Retention**: Configure appropriate retention policies

### Metrics

1. **Spring Boot Actuator**: Built-in metrics endpoint
2. **Prometheus Integration**: Add micrometer-prometheus dependency
3. **Custom Metrics**: Implement business-specific metrics

## Backup and Disaster Recovery

### Database Backups

1. **Automated Backups**: Configure RDS automated backups
2. **Point-in-Time Recovery**: Enable PITR for critical data
3. **Cross-Region Replication**: For disaster recovery

### Application State

1. **Stateless Design**: Ensure application is stateless
2. **Configuration Backup**: Version control all configuration
3. **Disaster Recovery Testing**: Regular DR drills

## Scaling

### Horizontal Pod Autoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: crm-app-hpa
  namespace: crm-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: crm-app-deployment
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Cluster Autoscaler

Configure cluster autoscaler for node-level scaling based on resource demands.

## Support and Maintenance

### Regular Maintenance Tasks

1. **Security Updates**: Regular base image and dependency updates
2. **Performance Monitoring**: Monitor application metrics and optimize
3. **Capacity Planning**: Review resource usage and plan for growth
4. **Backup Verification**: Test backup and restore procedures

### Upgrade Procedures

1. **Rolling Updates**: Use Kubernetes rolling update strategy
2. **Blue-Green Deployments**: For zero-downtime upgrades
3. **Canary Releases**: Gradual rollout of new versions

---

**Note**: This deployment guide is specific to the CRM Spring Boot application (Java 8, Spring Boot 1.5.10). Adjust configurations based on your specific requirements and environment constraints.

For additional support or questions, please refer to the application documentation or contact the development team.