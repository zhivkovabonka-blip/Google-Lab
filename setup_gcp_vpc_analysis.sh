#!/bin/bash
# Description: Automated setup for VPC Flow Logs and BigQuery Export
# Usage: chmod +x setup_gcp_vpc_analysis.sh && ./setup_gcp_vpc_analysis.sh

# Configuration (Modify Region/Zone as needed)
export REGION=europe-west4
export ZONE=europe-west4-a
export PROJECT_ID=$(gcloud config get-value project)

echo "Starting deployment in project: $PROJECT_ID..."

# 1. Create Custom VPC and Subnet
gcloud compute networks create vpc-net --subnet-mode=custom

gcloud compute networks subnets create vpc-subnet \
    --network=vpc-net \
    --range=10.1.3.0/24 \
    --region=$REGION \
    --enable-flow-logs \
    --logging-aggregation-interval=interval-5-sec \
    --logging-flow-sampling=0.5 \
    --logging-metadata=include-all

# 2. Configure Firewall Rules
gcloud compute firewall-rules create allow-http-ssh \
    --network=vpc-net \
    --allow=tcp:22,tcp:80 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=http-server

# 3. Create Web Server Instance
gcloud compute instances create web-server \
    --project=$PROJECT_ID \
    --zone=$ZONE \
    --machine-type=e2-micro \
    --network=vpc-net \
    --subnet=vpc-subnet \
    --tags=http-server \
    --metadata=startup-script='#! /bin/bash
        apt-get update
        apt-get install -y apache2
        echo "<!doctype html><html><body><h1>Cloud VPC Monitoring Active</h1></body></html>" > /var/www/html/index.html'

# 4. Setup BigQuery Export
bq --location=EU mk -d bq_vpcflows

gcloud logging sinks create bq_vpcflows \
    bigquery.googleapis.com/projects/$PROJECT_ID/datasets/bq_vpcflows \
    --log-filter='resource.type="gce_subnetwork" AND logName="projects/'$PROJECT_ID'/logs/compute.googleapis.com%2Fvpc_flows"'

# 5. Grant IAM Permissions for Sink
export LOG_SA=$(gcloud logging sinks describe bq_vpcflows --format='get(writerIdentity)')
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=$LOG_SA \
    --role='roles/bigquery.dataEditor'

echo "Setup Complete. Visit the External IP of 'web-server' to generate traffic."
