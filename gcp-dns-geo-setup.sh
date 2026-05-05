#!/bin/bash

# Configuration - Update zones if necessary
export ZONE_1="us-central1-c"
export ZONE_2="europe-central2-c"
export ZONE_3="asia-east1-c"
export REGION_1="us-central1"
export REGION_2="europe-central2"

echo "Starting Infrastructure Deployment..."

# Enable necessary APIs
gcloud services enable compute.googleapis.com dns.googleapis.com

# Create Firewall Rules
gcloud compute firewall-rules create fw-default-iapproxy \
    --network=default --action=ALLOW --rules=tcp:22,icmp \
    --source-ranges=35.235.240.0/20

gcloud compute firewall-rules create allow-http-traffic \
    --network=default --action=ALLOW --rules=tcp:80 \
    --source-ranges=0.0.0.0/0 --target-tags=http-server

# Create Client VMs
gcloud compute instances create us-client-vm --machine-type=e2-micro --zone=$ZONE_1 --async
gcloud compute instances create europe-client-vm --machine-type=e2-micro --zone=$ZONE_2 --async
gcloud compute instances create asia-client-vm --machine-type=e2-micro --zone=$ZONE_3 --async

# Create Web Servers with Startup Scripts
gcloud compute instances create us-web-vm \
    --machine-type=e2-micro --zone=$ZONE_1 --tags=http-server \
    --metadata=startup-script="#! /bin/bash
    apt-get update && apt-get install apache2 -y
    echo 'Page served from: $REGION_1' > /var/www/html/index.html" --async

gcloud compute instances create europe-web-vm \
    --machine-type=e2-micro --zone=$ZONE_2 --tags=http-server \
    --metadata=startup-script="#! /bin/bash
    apt-get update && apt-get install apache2 -y
    echo 'Page served from: $REGION_2' > /var/www/html/index.html"

echo "Waiting for instances to initialize..."
sleep 40

# DNS Setup
export US_WEB_IP=$(gcloud compute instances describe us-web-vm --zone=$ZONE_1 --format="value(networkInterfaces.networkIP)")
export EUROPE_WEB_IP=$(gcloud compute instances describe europe-web-vm --zone=$ZONE_2 --format="value(networkInterfaces.networkIP)")

gcloud dns managed-zones create example --dns-name=example.com --networks=default --visibility=private
gcloud dns record-sets create geo.example.com --ttl=5 --type=A --zone=example \
    --routing-policy-type=GEO --routing-policy-data="$REGION_1=$US_WEB_IP;$REGION_2=$EUROPE_WEB_IP"

echo "Deployment Complete."
