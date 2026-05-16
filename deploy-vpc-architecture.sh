#!/bin/bash

# ====================================================================
# GOOGLE CLOUD VPC NETWORK AUTOMATION SCRIPT
# Description: Automatically creates custom VPC networks, firewall rules, 
#              and compute instances (including a Multi-NIC appliance).
# ====================================================================

# Configuration Variables - Change according to your lab requirements
REGION_1="us-west1"
ZONE_1="us-west1-c"
REGION_2="us-east4" 

echo "=================================================="
echo "STARTING AUTOMATION FOR VPC NETWORKING LAB"
echo "=================================================="

# 1. Create Custom VPC Networks
echo "Creating managementnet network..."
gcloud compute networks create managementnet --subnet-mode=custom

echo "Creating privatenet network..."
gcloud compute networks create privatenet --subnet-mode=custom

# 2. Create Subnets
echo "Creating managementsubnet-1..."
gcloud compute networks subnets create managementsubnet-1 \
    --network=managementnet \
    --region=$REGION_1 \
    --range=10.130.0.0/20

echo "Creating privatesubnet-1..."
gcloud compute networks subnets create privatesubnet-1 \
    --network=privatenet \
    --region=$REGION_1 \
    --range=172.16.0.0/24

echo "Creating privatesubnet-2..."
gcloud compute networks subnets create privatesubnet-2 \
    --network=privatenet \
    --region=$REGION_2 \
    --range=172.20.0.0/20

# 3. Create Firewall Rules (Allow SSH, ICMP, RDP)
echo "Creating firewall rule for managementnet..."
gcloud compute firewall-rules create managementnet-allow-icmp-ssh-rdp \
    --direction=INGRESS \
    --priority=1000 \
    --network=managementnet \
    --action=ALLOW \
    --rules=icmp,tcp:22,tcp:3389 \
    --source-ranges=0.0.0.0/0

echo "Creating firewall rule for privatenet..."
gcloud compute firewall-rules create privatenet-allow-icmp-ssh-rdp \
    --direction=INGRESS \
    --priority=1000 \
    --network=privatenet \
    --action=ALLOW \
    --rules=icmp,tcp:22,tcp:3389 \
    --source-ranges=0.0.0.0/0

# 4. Create Standard VM Instances
echo "Creating managementnet-vm-1..."
gcloud compute instances create managementnet-vm-1 \
    --zone=$ZONE_1 \
    --machine-type=e2-micro \
    --subnet=managementsubnet-1

echo "Creating privatenet-vm-1..."
gcloud compute instances create privatenet-vm-1 \
    --zone=$ZONE_1 \
    --machine-type=e2-micro \
    --subnet=privatesubnet-1

# 5. Create Multi-NIC VM Instance (Network Appliance)
echo "Creating vm-appliance with multiple NICs..."
gcloud compute instances create vm-appliance \
    --zone=$ZONE_1 \
    --machine-type=e2-standard-4 \
    --network-interface=subnet=privatesubnet-1 \
    --network-interface=subnet=managementsubnet-1 \
    --network-interface=subnet=mynetwork

echo "=================================================="
echo "LAB TASK AUTOMATION COMPLETED SUCCESSFULLY!"
echo "=================================================="
