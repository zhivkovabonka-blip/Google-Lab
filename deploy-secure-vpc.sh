#!/bin/bash

# ========================================================================================
# Script Name: deploy-secure-vpc.sh
# Description: Automates the creation of a private VPC, firewall, VM, and Cloud NAT.
# Author: Your Name
# ========================================================================================

# Variables (Update as per lab/project requirements)
REGION="us-west1"
ZONE="us-west1-c"
NETWORK_NAME="privatenet"
SUBNET_NAME="privatenet-us"
VM_NAME="vm-internal"
IP_RANGE="10.130.0.0/20"

echo "🚀 Starting deployment in region $REGION..."

# 1. Create VPC Network (Custom mode)
gcloud compute networks create $NETWORK_NAME --subnet-mode=custom

# 2. Create Subnet with Private Google Access enabled
gcloud compute networks subnets create $SUBNET_NAME \
    --network=$NETWORK_NAME \
    --region=$REGION \
    --range=$IP_RANGE \
    --enable-private-ip-google-access

# 3. Create Firewall Rule to allow SSH via IAP (Identity-Aware Proxy)
gcloud compute firewall-rules create "$NETWORK_NAME-allow-ssh" \
    --network=$NETWORK_NAME \
    --allow=tcp:22 \
    --source-ranges=35.235.240.0/20 \
    --description="Allow SSH from IAP proxy range"

# 4. Create VM Instance (No Public IP)
gcloud compute instances create $VM_NAME \
    --zone=$ZONE \
    --machine-type=e2-standard-2 \
    --network=$NETWORK_NAME \
    --subnet=$SUBNET_NAME \
    --no-address \
    --image-family=debian-12 \
    --image-project=debian-cloud \
    --metadata=enable-oslogin=TRUE

# 5. Configure Cloud Router (Required for NAT)
gcloud compute routers create nat-router \
    --network=$NETWORK_NAME \
    --region=$REGION

# 6. Configure Cloud NAT Gateway
gcloud compute networks nat create nat-config \
    --router=nat-router \
    --region=$REGION \
    --auto-allocate-nat-external-ip \
    --nat-all-subnet-ip-ranges

echo "✅ Infrastructure deployed successfully!"
echo "🔗 To connect to your private VM, use:"
echo "gcloud compute ssh $VM_NAME --zone=$ZONE --tunnel-through-iap"
