#!/bin/bash

# ==========================================================
# 1. LAB CREDENTIALS & EXACT ASSIGNED TAGS
# ==========================================================
PROJECT_ID="qwiklabs-gcp-00-f8e8abdfb89c"
ZONE="us-east4-c"
BASTION_NAME="bastion"
JUICE_SHOP_NAME="juice-shop"
VPC_NAME="acme-vpc"
MGMT_SUBNET="acme-mgmt-subnet"

# Your exact lab-assigned tags/rule names
SSH_IAP_TAG="grant-ssh-iap-ingress-ql-563"
HTTP_TAG="grant-http-ingress-ql-563"
SSH_INTERNAL_TAG="grant-ssh-internal-ingress-ql-563"

echo "=========================================================="
echo "STARTING GOOGLE CLOUD SECURITY AUTOMATION"
echo "=========================================================="

# Force gcloud to target Project 1
gcloud config set project $PROJECT_ID

# Step 2: Delete the overly permissive 'open-access' firewall rule (Task 1 Fix)
echo "--> Removing overly permissive open-access rule..."
gcloud compute firewall-rules delete open-access --project=$PROJECT_ID --quiet 2>/dev/null || echo "Rule open-access already deleted or not found."

# Step 3: Start/Ensure the Bastion Host is running
echo "--> Starting bastion host instance..."
gcloud compute instances start $BASTION_NAME --zone=$ZONE --project=$PROJECT_ID --quiet

# Step 4: Apply the precise Network Tags to VM instances
echo "--> Applying exact network tags..."
gcloud compute instances add-tags $BASTION_NAME --tags=$SSH_IAP_TAG --zone=$ZONE --project=$PROJECT_ID
gcloud compute instances add-tags $JUICE_SHOP_NAME --tags=$HTTP_TAG,$SSH_INTERNAL_TAG --zone=$ZONE --project=$PROJECT_ID

# Step 5: Create Firewall Rule - SSH via IAP to Bastion
echo "--> Creating firewall rule: $SSH_IAP_TAG..."
gcloud compute firewall-rules create $SSH_IAP_TAG \
    --project=$PROJECT_ID \
    --network=$VPC_NAME \
    --direction=INGRESS \
    --action=ALLOW \
    --source-ranges=35.235.240.0/20 \
    --target-tags=$SSH_IAP_TAG \
    --rules=tcp:22

# Step 6: Create Firewall Rule - Public HTTP to Juice-Shop
echo "--> Creating firewall rule: $HTTP_TAG..."
gcloud compute firewall-rules create $HTTP_TAG \
    --project=$PROJECT_ID \
    --network=$VPC_NAME \
    --direction=INGRESS \
    --action=ALLOW \
    --source-ranges=0.0.0.0/0 \
    --target-tags=$HTTP_TAG \
    --rules=tcp:80

# Step 7: Dynamically fetch the management subnet IP range
echo "--> Fetching subnet IP range..."
SUBNET_RANGE=$(gcloud compute networks subnets describe $MGMT_SUBNET --project=$PROJECT_ID --region=${ZONE%-*} --format="value(ipCidrRange)")

# Step 8: Create Firewall Rule - Internal SSH from Bastion to Juice-Shop
echo "--> Creating firewall rule: $SSH_INTERNAL_TAG..."
gcloud compute firewall-rules create $SSH_INTERNAL_TAG \
    --project=$PROJECT_ID \
    --network=$VPC_NAME \
    --direction=INGRESS \
    --action=ALLOW \
    --source-ranges=$SUBNET_RANGE \
    --target-tags=$SSH_INTERNAL_TAG \
    --rules=tcp:22

echo "=========================================================="
echo "ALL CONFIGURATIONS APPLIED! RUN THE FINAL TUNNEL COMMAND:"
echo "=========================================================="
gcloud compute ssh $BASTION_NAME --project=$PROJECT_ID --zone=$ZONE --tunnel-through-iap --command="gcloud compute ssh $JUICE_SHOP_NAME --zone=$ZONE --internal-ip"
