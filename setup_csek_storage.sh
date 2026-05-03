#!/bin/bash

# =================================================================
# Script: setup_csek_storage.sh
# Description: Automates GCP infrastructure setup and CSEK encryption
# Author: [Your Name/GitHub Handle]
# =================================================================

# 1. Configuration - Replace BUCKET_NAME with your specific ID
export PROJECT_ID=$(gcloud config get-value project)
export BUCKET_NAME="qwiklabs-gcp-01-17b2a4d0ab26-csek"
export REGION="us-west1"
export ZONE="us-west1-b"

echo "🚀 Starting deployment for Project: $PROJECT_ID..."

# 2. IAM: Create Service Account
echo "👤 Creating Service Account: cseklab..."
gcloud iam service-accounts create cseklab --display-name="cseklab"

# 3. IAM: Assign Storage Admin Role
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:cseklab@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/storage.admin"

# 4. Infrastructure: Create VM Instance with CSEK Scopes
echo "🖥️ Provisioning Compute Instance: cseklab-vm..."
gcloud compute instances create cseklab-vm \
    --zone=$ZONE \
    --machine-type=e2-standard-2 \
    --service-account=cseklab@$PROJECT_ID.iam.gserviceaccount.com \
    --scopes=https://www.googleapis.com/auth/devstorage.full_control \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --quiet

# 5. Storage: Create Bucket
echo "🪣 Creating Cloud Storage Bucket: $BUCKET_NAME..."
gsutil mb -l us gs://$BUCKET_NAME

# 6. Security: Generate CSEK Key & Configure .boto
echo "🔐 Generating 256-bit AES Key..."
export MY_KEY=$(openssl rand 32 | openssl base64)

# Ensure .boto exists and inject encryption key
touch ~/.boto
cat << EOF > ~/.boto
[GSUtil]
encryption_key = $MY_KEY
EOF

# 7. Data: Download and Encrypt Upload
echo "📥 Downloading sample data and uploading with CSEK..."
curl -s https://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-common/ClusterSetup.html > setup.html
gsutil cp setup.html gs://$BUCKET_NAME

echo "✅ Deployment Complete!"
echo "Verify encryption with: gsutil ls -L gs://$BUCKET_NAME/setup.html"
