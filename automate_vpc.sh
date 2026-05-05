#!/bin/bash
# GCP VPC Automation Script
# Project: "Ръководство за твоя проект"

# Variables
ZONE_1="asia-east1-a"
ZONE_2="asia-east1-b"

echo "Step 1: Creating VPC network..."
gcloud compute networks create mynetwork --subnet-mode=auto

echo "Step 2: Creating instances..."
gcloud compute instances create mynet-vm-1 --machine-type e2-micro --zone=$ZONE_1 --network=mynetwork
gcloud compute instances create mynet-vm-2 --machine-type e2-micro --zone=$ZONE_2 --network=mynetwork

echo "Step 3: Cleaning up default network..."
gcloud compute firewall-rules delete default-allow-icmp default-allow-internal default-allow-rdp default-allow-ssh --quiet
gcloud compute networks delete default --quiet

echo "Step 4: Configuring Firewall rules..."
IP_CS=$(curl -s https://api.ipify.org)
gcloud compute firewall-rules create mynetwork-ingress-allow-ssh-from-cs \
    --network mynetwork --action ALLOW --direction INGRESS \
    --rules tcp:22 --source-ranges $IP_CS --target-tags=lab-ssh

gcloud compute instances add-tags mynet-vm-1 --zone $ZONE_1 --tags lab-ssh
gcloud compute instances add-tags mynet-vm-2 --zone $ZONE_2 --tags lab-ssh

gcloud compute firewall-rules create mynetwork-ingress-allow-icmp-internal \
    --network mynetwork --action ALLOW --direction INGRESS --rules icmp \
    --source-ranges 10.128.0.0/9

echo "Step 5: Setting Priority and Egress rules..."
gcloud compute firewall-rules create mynetwork-ingress-deny-icmp-all \
    --network mynetwork --action DENY --direction INGRESS --rules icmp \
    --priority 2000

gcloud compute firewall-rules create mynetwork-egress-deny-icmp-all \
    --network mynetwork --action DENY --direction EGRESS --rules icmp \
    --priority 10000

echo "✅ Deployment Successful!"
