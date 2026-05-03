#!/bin/bash
# Google Cloud VPC Networking Automation
# Author: Your Name

echo "Starting VPC Network Setup..."

# Create VPC
gcloud compute networks create mynetwork --subnet-mode=auto

# Create Instances
gcloud compute instances create mynet-vm-1 --machine-type e2-micro --zone=us-east4-b --network=mynetwork
gcloud compute instances create mynet-vm-2 --machine-type e2-micro --zone=asia-southeast1-c --network=mynetwork

# Firewall Rules
ip=$(curl -s https://api.ipify.org)
gcloud compute firewall-rules create mynetwork-ingress-allow-ssh-from-cs \
    --network mynetwork --action ALLOW --direction INGRESS --rules tcp:22 --source-ranges $ip --target-tags=lab-ssh

gcloud compute instances add-tags mynet-vm-1 --zone=us-east4-b --tags lab-ssh
gcloud compute instances add-tags mynet-vm-2 --zone=asia-southeast1-c --tags lab-ssh

# ICMP Rules (Internal Allow and Global Deny)
gcloud compute firewall-rules create mynetwork-ingress-allow-icmp-internal \
    --network mynetwork --action ALLOW --direction INGRESS --rules icmp --source-ranges 10.128.0.0/9

gcloud compute firewall-rules create mynetwork-ingress-deny-icmp-all \
    --network mynetwork --action DENY --direction INGRESS --rules icmp --priority 2000

gcloud compute firewall-rules create mynetwork-egress-deny-icmp-all \
    --network mynetwork --action DENY --direction EGRESS --rules icmp --priority 10000

echo "Setup Complete."
