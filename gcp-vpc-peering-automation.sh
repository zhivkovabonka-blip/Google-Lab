#!/bin/bash
# ==============================================================================
# Title:        Google Cloud Platform VPC Network Peering Automation
# Description:  Automates the creation of custom VPCs, subnets, VM instances, 
#               and establishes a bidirectional VPC Network Peering across two 
#               distinct GCP projects.
# Author:       Your Name / GitHub Username
# Date:         2026
# ==============================================================================

# Exit immediately if a command exits with a non-zero status
set -e

# --- Configuration ---
PROJECT_ID_A="qwiklabs-gcp-00-35c7746c593a"
PROJECT_ID_B="qwiklabs-gcp-04-db2b621122bd"

REGION_A="europe-west4"
ZONE_A="europe-west4-a"

REGION_B="us-east4"
ZONE_B="us-east4-c"

echo "========================================="
echo " Starting GCP Infrastructure Deployment "
echo "========================================="

# --- STEP 1: Provision Project-A Resources ---
echo "Configuring Project-A ($PROJECT_ID_A)..."
gcloud config set project "$PROJECT_ID_A"

gcloud compute networks create network-a --subnet-mode=custom

gcloud compute networks subnets create network-a-subnet \
    --network=network-a \
    --range=10.0.0.0/16 \
    --region="$REGION_A"

gcloud compute instances create vm-a \
    --zone="$ZONE_A" \
    --network=network-a \
    --subnet=network-a-subnet \
    --machine-type=e2-small

# Enable SSH and ICMP Firewall Rule if it doesn't exist
gcloud compute firewall-rules create network-a-fw --network=network-a --allow=tcp:22,icmp || echo "Firewall rule already exists."

# --- STEP 2: Provision Project-B Resources ---
echo "Configuring Project-B ($PROJECT_ID_B)..."
gcloud config set project "$PROJECT_ID_B"

gcloud compute networks create network-b --subnet-mode=custom

gcloud compute networks subnets create network-b-subnet \
    --network=network-b \
    --range=10.8.0.0/16 \
    --region="$REGION_B"

gcloud compute instances create vm-b \
    --zone="$ZONE_B" \
    --network=network-b \
    --subnet=network-b-subnet \
    --machine-type=e2-small

gcloud compute firewall-rules create network-b-fw --network=network-b --allow=tcp:22,icmp || echo "Firewall rule already exists."

# --- STEP 3: Establish Bidirectional VPC Peering ---
echo "Establishing Multi-Project VPC Network Peering..."

# Peering from Network-A to Network-B
gcloud compute networks peerings create peer-ab \
    --network=network-a \
    --peer-project="$PROJECT_ID_B" \
    --peer-network=network-b \
    --project="$PROJECT_ID_A"

# Peering from Network-B to Network-A
gcloud compute networks peerings create peer-ba \
    --network=network-b \
    --peer-project="$PROJECT_ID_A" \
    --peer-network=network-a \
    --project="$PROJECT_ID_B"

echo "========================================="
echo " Deployment Successfully Completed!      "
echo "========================================="
