#!/bin/bash

# =================================================================
# Project: Container Dev Workshop
# Description: Infrastructure setup and deployment automation
# =================================================================

# 1. Setup environment variables
export PROJECT_ID=$(gcloud config get-value project)
export REGION=us-east1
export ZONE=us-east1-b

# 2. Create GKE cluster
echo "Creating GKE cluster..."
gcloud container clusters create container-dev-cluster --zone=$ZONE

# 3. Create Maven repository in Artifact Registry
echo "Creating Maven repository..."
gcloud artifacts repositories create container-dev-java-repo \
    --repository-format=maven \
    --location=$REGION \
    --description="Java package repository for Container Dev Workshop"

# 4. Deploy application using Skaffold
echo "Deploying application with Skaffold..."
skaffold run --default-repo=us-east1-docker.pkg.dev/$PROJECT_ID/container-dev-repo
# Project Guide: Container Dev Workshop

This project demonstrates the development lifecycle in Google Cloud (GCP). It includes infrastructure setup, containerization, and artifact management.

## Technologies Used
- **Google Kubernetes Engine (GKE):** Cluster management.
- **Artifact Registry:** Storage for Docker images and Maven packages.
- **Skaffold & Cloud Code:** CI/CD automation and hot-reloading for code development.

## How It Works
1. **Infrastructure:** The project automatically deploys a Java application to a GKE cluster.
2. **Artifacts:** We use a Maven repository in Artifact Registry to manage dependencies.
3. **Development:** Through Cloud Code, every code change is automatically redeployed, enabling rapid testing.

## Status
✅ Lab successfully completed.
