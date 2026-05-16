#!/bin/bash
# ====================================================================
# GCP NETWORK AND SECURITY ROLES AUTOMATION
# ====================================================================
# This script automates the deployment of two Nginx web servers (Blue/Green),
# configures custom firewall rules, and sets up a Service Account to test 
# GCP IAM Network Admin vs. Security Admin roles.
# ====================================================================

export REGION="europe-west3"
export ZONE="europe-west3-b"
export PROJECT_ID=$(gcloud config get-value project)

echo "Starting deployment in Zone: $ZONE for Project: $PROJECT_ID..."

# 1. Create Blue Server (With Network Tag)
echo "Creating 'blue' VM instance..."
gcloud compute instances create blue \
    --zone=$ZONE \
    --machine-type=e2-medium \
    --tags=web-server \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --metadata=startup-script='#!/bin/bash
        apt-get update && apt-get install nginx-light -y
        echo "<h1>Welcome to the blue server!</h1>" > /var/www/html/index.nginx-debian.html
        systemctl restart nginx'

# 2. Create Green Server (Without Network Tag)
echo "Creating 'green' VM instance..."
gcloud compute instances create green \
    --zone=$ZONE \
    --machine-type=e2-medium \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --metadata=startup-script='#!/bin/bash
        apt-get update && apt-get install nginx-light -y
        echo "<h1>Welcome to the green server!</h1>" > /var/www/html/index.nginx-debian.html
        systemctl restart nginx'

# 3. Create Tagged Firewall Rule
echo "Creating firewall rule 'allow-http-web-server'..."
gcloud compute firewall-rules create allow-http-web-server \
    --network=default \
    --direction=INGRESS \
    --priority=1000 \
    --action=ALLOW \
    --target-tags=web-server \
    --source-ranges=0.0.0.0/0 \
    --rules=tcp:80,icmp

# 4. Create Test VM
echo "Creating 'test-vm' instance..."
gcloud compute instances create test-vm \
    --machine-type=e2-micro \
    --subnet=default \
    --zone=$ZONE

# 5. Setup Service Account and IAM Roles
echo "Creating service account and generating credentials..."
gcloud iam service-accounts create network-admin --display-name="Network-admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:network-admin@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/compute.networkAdmin"

gcloud iam service-accounts keys create credentials.json \
    --iam-account=network-admin@$PROJECT_ID.iam.gserviceaccount.com

echo "Deployment finished successfully!"
