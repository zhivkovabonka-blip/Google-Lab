#!/bin/bash
# GCP Multi-Project Monitoring Lab
# Project 1 (Monitoring): PROJECT_1
# Project 2 (Worker 1):   PROJECT_2
# Project 3 (Worker 2):   PROJECT_3

set -e

PROJECT_1="PROJECT_1"
PROJECT_2="PROJECT_2"
PROJECT_3="PROJECT_3"

echo "=== TASK 1: Create VMs and install NGINX ==="

gcloud config set project $PROJECT_2
gcloud compute instances create worker-1-server \
  --zone=us-central1-b \
  --machine-type=e2-medium \
  --image-family=debian-12 \
  --image-project=debian-cloud \
  --boot-disk-size=10GB \
  --boot-disk-type=pd-balanced \
  --tags=http-server

gcloud compute firewall-rules create default-allow-http \
  --allow=tcp:80 \
  --target-tags=http-server 2>/dev/null || true

sleep 40

gcloud compute ssh worker-1-server --zone=us-central1-b \
  --tunnel-through-iap --quiet \
  --command="sudo apt-get update -y && sudo apt-get install -y nginx"

gcloud config set project $PROJECT_3
gcloud compute instances create worker-2-server \
  --zone=us-central1-b \
  --machine-type=e2-medium \
  --image-family=debian-12 \
  --image-project=debian-cloud \
  --boot-disk-size=10GB \
  --boot-disk-type=pd-balanced \
  --tags=http-server

gcloud compute firewall-rules create default-allow-http \
  --allow=tcp:80 \
  --target-tags=http-server 2>/dev/null || true

sleep 40

gcloud compute ssh worker-2-server --zone=us-central1-b \
  --tunnel-through-iap --quiet \
  --command="sudo apt-get update -y && sudo apt-get install -y nginx"

echo "=== TASK 3: Add labels ==="

gcloud compute instances add-labels worker-1-server \
  --zone=us-central1-b \
  --project=$PROJECT_2 \
  --labels=component=frontend,stage=dev

gcloud compute instances add-labels worker-2-server \
  --zone=us-central1-b \
  --project=$PROJECT_3 \
  --labels=component=frontend,stage=test

echo "=== Done! Complete Tasks 2, 3, 4, 5 manually in the Console ==="
