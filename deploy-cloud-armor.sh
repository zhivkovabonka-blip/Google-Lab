#!/bin/bash

# ==============================================================================
# Google Cloud Armor WAF & Load Balancer Deployment Script
# Target App: OWASP Juice Shop (Container-based VM)
# ==============================================================================

# 1. SETUP PARAMETERS (Modify as needed)
PROJECT_ID="qwiklabs-gcp-00-94867994fb81"
NETWORK_NAME="ca-lab-vpc"
SUBNET_NAME="ca-lab-subnet"
REGION="us-east1"
ZONE="us-east1-c"
INSTANCE_NAME="owasp-juice-shop-app"
INSTANCE_GROUP_NAME="juice-shop-group"
POLICY_NAME="block-with-modsec-crs"
BACKEND_NAME="juice-shop-backend"

echo "=== [1/6] Setting up GCP Project Context ==="
gcloud config set project $PROJECT_ID

echo "=== [2/6] Creating Custom VPC and Subnet ==="
gcloud compute networks create $NETWORK_NAME --subnet-mode custom

gcloud compute networks subnets create $SUBNET_NAME \
        --network $NETWORK_NAME \
        --range 10.0.0.0/24 \
        --region $REGION

echo "=== [3/6] Configuring Initial Firewall Rules ==="
gcloud compute firewall-rules create allow-js-site \
    --allow tcp:3000 \
    --network $NETWORK_NAME

gcloud compute firewall-rules create allow-health-check \
    --network=$NETWORK_NAME \
    --action=allow \
    --direction=ingress \
    --source-ranges=130.211.0.0/22,35.191.0.0/16 \
    --target-tags=allow-healthcheck \
    --rules=tcp

echo "=== [4/6] Deploying OWASP Juice Shop Container Instance ==="
gcloud compute instances create-with-container $INSTANCE_NAME \
     --container-image bkimminich/juice-shop \
     --network $NETWORK_NAME \
     --subnet $SUBNET_NAME \
     --private-network-ip=10.0.0.3 \
     --machine-type n1-standard-2 \
     --zone $ZONE \
     --tags allow-healthcheck

echo "=== [5/6] Creating Network Architecture & Load Balancer ==="
gcloud compute instance-groups unmanaged create $INSTANCE_GROUP_NAME --zone=$ZONE
gcloud compute instance-groups unmanaged add-instances $INSTANCE_GROUP_NAME --zone=$ZONE --instances=$INSTANCE_NAME
gcloud compute instance-groups unmanaged set-named-ports $INSTANCE_GROUP_NAME --named-ports=http:3000 --zone=$ZONE

gcloud compute health-checks create tcp tcp-port-3000 --port 3000

gcloud compute backend-services create $BACKEND_NAME \
        --protocol HTTP \
        --port-name http \
        --health-checks tcp-port-3000 \
        --enable-logging \
        --global

gcloud compute backend-services add-backend $BACKEND_NAME \
        --instance-group=$INSTANCE_GROUP_NAME \
        --instance-group-zone=$ZONE \
        --global

gcloud compute url-maps create juice-shop-loadbalancer --default-service $BACKEND_NAME
gcloud compute target-http-proxies create juice-shop-proxy --url-map juice-shop-loadbalancer
gcloud compute forwarding-rules create juice-shop-rule --global --target-http-proxy=juice-shop-proxy --ports=80

echo "=== [6/6] Configuring Cloud Armor WAF Policy & OWASP Rules ==="
gcloud compute security-policies create $POLICY_NAME --description "Block with OWASP ModSecurity CRS"
gcloud compute security-policies rules update 2147483647 --security-policy $POLICY_NAME --action "deny-403"

# Whitelist administrator IP dynamically
MY_IP=$(curl -s ifconfig.me)
gcloud compute security-policies rules create 10000 --security-policy $POLICY_NAME --description "allow admin IP" --src-ip-ranges "$MY_IP/32" --action "allow"

# Apply Preconfigured OWASP Protection Rules
gcloud compute security-policies rules create 9000 --security-policy $POLICY_NAME --description "block LFI" --expression "evaluatePreconfiguredExpr('lfi-stable')" --action "deny-403"
gcloud compute security-policies rules create 9001 --security-policy $POLICY_NAME --description "block RCE" --expression "evaluatePreconfiguredExpr('rce-stable')" --action "deny-403"
gcloud compute security-policies rules create 9002 --security-policy $POLICY_NAME --description "block scanners" --expression "evaluatePreconfiguredExpr('scannerdetection-stable')" --action "deny-403"
gcloud compute security-policies rules create 9003 --security-policy $POLICY_NAME --description "block protocol attacks" --expression "evaluatePreconfiguredExpr('protocolattack-stable')" --action "deny-403"
gcloud compute security-policies rules create 9004 --security-policy $POLICY_NAME --description "block session fixation" --expression "evaluatePreconfiguredExpr('sessionfixation-stable')" --action "deny-403"

gcloud compute backend-services update $BACKEND_NAME --security-policy $POLICY_NAME --global

echo "=== Architecture Deployment Successfully Completed! ==="
PUBLIC_SVC_IP="$(gcloud compute forwarding-rules describe juice-shop-rule --global --format="value(IPAddress)")"
echo "Load Balancer Public VIP: http://$PUBLIC_SVC_IP"
README.md
# Google Cloud Armor WAF Deployment & Automation

This repository contains an automated Bash script to deploy a secure web application architecture on Google Cloud Platform (GCP). It leverages an HTTP Load Balancer combined with **Google Cloud Armor** to defend against common web vulnerabilities using OWASP ModSecurity Core Rule Sets (CRS).

## Architecture Diagram Overview
The infrastructure deployed includes:
* **Custom VPC Network & Subnet** (`10.0.0.0/24`) in `us-east1`.
* **Compute Engine Instance** running **OWASP Juice Shop** inside a secure container.
* **Unmanaged Instance Group** mapped to port 3000.
* **Global HTTP Load Balancer** acting as the frontend proxy (port 80).
* **Cloud Armor Security Policy** enforcing WAF rule mitigation.

## Features & Mitigations Automated
The script configures individual Cloud Armor rules to block the following attack vectors with a `403 Forbidden` response:
1. **Local File Inclusion (LFI)** (`lfi-stable`)
2. **Remote Code Execution (RCE)** (`rce-stable`)
3. **Malicious Scanners & Crawlers** (`scannerdetection-stable`)
4. **Protocol Exploits / HTTP Splitting** (`protocolattack-stable`)
5. **Session Fixation Attacks** (`sessionfixation-stable`)

*Note: The script automatically fetches your local public IP and adds it to an IP whitelist rule (Priority 10000) so administrator access is preserved during testing.*

## Prerequisites
* A Google Cloud Platform account with an active project.
* Google Cloud SDK (`gcloud` CLI) installed and authenticated, or execution via GCP **Cloud Shell**.

## Deployment Instructions

1. Clone this repository or download the script file:
```bash
   git clone [https://github.com/YOUR_USERNAME/YOUR_REPOSITORY_NAME.git](https://github.com/YOUR_USERNAME/YOUR_REPOSITORY_NAME.git)
   cd YOUR_REPOSITORY_NAME
