# Multi-stage Dockerfile for CRM Spring Boot Application
# Build stage
FROM maven:3.9.4-eclipse-temurin-8 AS builder

WORKDIR /app

# Copy Maven configuration files
COPY CRM-master/pom.xml ./
COPY CRM-master/src ./src

# Build the application
RUN mvn clean package -DskipTests

# Runtime stage
FROM openjdk:8-jre-slim

# Install curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Set working directory
WORKDIR /app

# Copy JAR from build stage (correct JAR name based on pom.xml)
COPY --from=builder /app/target/crm-0.0.1-SNAPSHOT.jar app.jar

# Change ownership to non-root user
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Set JVM options
ENV JAVA_OPTS="-Xmx512m -Xms256m -server -Djava.security.egd=file:/dev/./urandom"

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/appinfo/health || exit 1

# Run the application
CMD ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]