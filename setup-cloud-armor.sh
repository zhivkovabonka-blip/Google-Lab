#!/bin/bash
# Google Cloud Armor Security Setup Script

# Variables
ZONE="us-central1-f"
LB_IP="34.102.226.83" # Замени с твоя реален LB IP

echo "--- Starting Security Configuration ---"

# 1. Capture the External IP of the Test VM
export TEST_VM_IP=$(gcloud compute instances describe access-test --zone=$ZONE --format="value(networkInterfaces[0].accessConfigs[0].externalIp)")
echo "Targeting Test VM IP: $TEST_VM_IP"

# 2. Create Cloud Armor Policy
gcloud compute security-policies create blocklist-access-test \
    --description="Policy to block malicious test VM access"

# 3. Add Deny Rule (404) for the specific IP
gcloud compute security-policies rules create 1000 \
    --security-policy=blocklist-access-test \
    --src-ip-ranges=$TEST_VM_IP \
    --action="deny-404"

# 4. Enable Logging and DDoS Protection
gcloud compute security-policies update blocklist-access-test \
    --enable-layer7-ddos-defense \
    --log-level=VERBOSE

# 5. Attach Policy to the Backend Service
gcloud compute backend-services update web-backend \
    --security-policy=blocklist-access-test \
    --global

echo "--- Configuration Applied Successfully ---"
