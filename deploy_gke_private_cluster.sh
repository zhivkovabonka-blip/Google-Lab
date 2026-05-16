#!/bin/bash
# ==============================================================================
# GKE Private Cluster Automation Script
# ==============================================================================
# Description: Automates the creation and configuration of GKE private clusters,
#              custom subnetworks, and master authorized networks.
# ==============================================================================

# SET YOUR REGION AND ZONE HERE
export REGION="us-east4"
export ZONE="us-east4-c"

echo "=== Task 1: Setting up region and zone ==="
gcloud config set compute/zone "$ZONE"
gcloud config set compute/region "$REGION"

echo "=== Task 2: Creating the first private-cluster ==="
gcloud beta container clusters create private-cluster \
    --enable-private-nodes \
    --master-ipv4-cidr 172.16.0.16/28 \
    --enable-ip-alias \
    --create-subnetwork "" \
    --machine-type e2-medium \
    --zone "$ZONE" \
    --quiet

echo "=== Task 3: Retrieving automatically created subnetwork ==="
SUBNET_NAME=$(gcloud compute networks subnets list --network default --format="value(name)" | grep private-cluster)
echo "Found subnetwork: $SUBNET_NAME"
gcloud compute networks subnets describe "$SUBNET_NAME" --region="$REGION"

echo "=== Task 4: Creating source-instance (Bastion Host) ==="
gcloud compute instances create source-instance \
    --zone="$ZONE" \
    --machine-type=e2-medium \
    --scopes 'https://www.googleapis.com/auth/cloud-platform' \
    --quiet

echo "Extracting external NAT IP dynamically..."
NAT_IP=$(gcloud compute instances describe source-instance --zone="$ZONE" --format="value(networkInterfaces[0].accessConfigs[0].natIP)")
MY_EXTERNAL_RANGE="${NAT_IP}/32"
echo "Source instance external IP: $MY_EXTERNAL_RANGE"

echo "Authorizing network for private-cluster..."
gcloud container clusters update private-cluster \
    --enable-master-authorized-networks \
    --master-authorized-networks "$MY_EXTERNAL_RANGE" \
    --zone "$ZONE" \
    --quiet

echo "Executing verification commands inside source-instance..."
gcloud compute ssh source-instance --zone="$ZONE" --quiet --command "
    sudo apt-get update && sudo apt-get install -y kubectl google-cloud-sdk-gke-gcloud-auth-plugin
    export ZONE=$ZONE
    gcloud container clusters get-credentials private-cluster --zone=\$ZONE
    echo '--- Verifying Node IP Addresses (ExternalIP should be empty) ---'
    kubectl get nodes --output wide
"

echo "=== Task 5: Cleaning up the first private-cluster ==="
gcloud container clusters delete private-cluster --zone="$ZONE" --quiet

echo "=== Task 6: Creating custom subnetwork (my-subnet) ==="
gcloud compute networks subnets create my-subnet \
    --network default \
    --range 10.0.4.0/22 \
    --enable-private-ip-google-access \
    --region="$REGION" \
    --secondary-range my-svc-range=10.0.32.0/20,my-pod-range=10.4.0.0/14 \
    --quiet

echo "Creating private-cluster2 in the custom subnetwork..."
gcloud beta container clusters create private-cluster2 \
    --enable-private-nodes \
    --enable-ip-alias \
    --master-ipv4-cidr 172.16.0.32/28 \
    --subnetwork my-subnet \
    --services-secondary-range-name my-svc-range \
    --cluster-secondary-range-name my-pod-range \
    --zone="$ZONE" \
    --machine-type e2-medium \
    --quiet

echo "Authorizing external IP for private-cluster2..."
gcloud container clusters update private-cluster2 \
    --enable-master-authorized-networks \
    --zone="$ZONE" \
    --master-authorized-networks "$MY_EXTERNAL_RANGE" \
    --quiet

echo "Final verification of private-cluster2 via source-instance..."
gcloud compute ssh source-instance --zone="$ZONE" --quiet --command "
    export ZONE=$ZONE
    gcloud container clusters get-credentials private-cluster2 --zone=\$ZONE
    echo '--- Verifying Node IP Addresses for Cluster 2 ---'
    kubectl get nodes --output wide
"
# Google Kubernetes Engine (GKE) Private Cluster Automation

An automated Bash script designed to easily configure, provision, and test secure GKE private clusters on Google Cloud Platform (GCP). This project demonstrates cloud security best practices by isolating Kubernetes worker nodes from the public internet using custom subnetworks and Master Authorized Networks.

## 🚀 Features

- **Automated Infrastructure Setup:** Configures default and custom VPC subnetworks with primary and secondary IP ranges for pods and services.
- **Enhanced Security:** Provisions GKE Private Clusters with no external IP addresses allocated to nodes.
- **Bastion Host Integration:** Dynamically launches a compute instance (`source-instance`), fetches its external NAT IP, and allowlists it automatically.
- **Remote Verification:** Interacts with the private clusters completely over non-interactive SSH, setting up `kubectl` and the GKE auth plugin on the fly.

## 🛠️ Prerequisites

Before running the script, ensure you have:
- A Google Cloud Project with billing enabled.
- [Google Cloud SDK (gcloud)](https://cloud.google.com/sdk) installed and authenticated, or access to Google Cloud Shell.

## 💻 Usage

1. **Clone the repository:**
   ```bash
   git clone [https://github.com/YOUR_USERNAME/gke-private-cluster-automation.git](https://github.com/YOUR_USERNAME/gke-private-cluster-automation.git)
   cd gke-private-cluster-automation
echo "=== ALL TASKS COMPLETED SUCCESSFULLY! ==="
README.md
