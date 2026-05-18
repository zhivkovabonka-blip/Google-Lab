#!/bin/bash

# ==============================================================================
# GCP IAM and Cloud Storage Automation Script
# ==============================================================================

# 1. Define configuration variables[cite: 1]
export PROJECT_ID="qwiklabs-gcp-03-a14fe1ed4962"[cite: 1]
export USERNAME_2="student-01-66df584c0ee5@qwiklabs.net"[cite: 1]
export BUCKET_NAME="bucket-$PROJECT_ID"[cite: 1]

# Ensure the correct project context is selected[cite: 1]
gcloud config set project $PROJECT_ID[cite: 1]

# ------------------------------------------------------------------------------
# TASK 2: Create a Storage Bucket and Upload Sample File
# ------------------------------------------------------------------------------
echo "=== Starting Task 2 ==="[cite: 1]
# Create a Multi-Region Storage Bucket[cite: 1]
gcloud storage buckets create gs://$BUCKET_NAME --location=US[cite: 1]

# Create the sample text file locally[cite: 1]
echo "This is a sample file for IAM testing." > sample.txt[cite: 1]

# Upload the file to the newly created bucket[cite: 1]
gcloud storage cp sample.txt gs://$BUCKET_NAME/sample.txt[cite: 1]
echo "=== Task 2 completed! You can now click 'Check my progress' ==="[cite: 1]

# ------------------------------------------------------------------------------
# TASK 3: Remove Project-Wide Viewer Role from User 2
# ------------------------------------------------------------------------------
echo "=== Starting Task 3 ==="[cite: 1]
gcloud projects remove-iam-policy-binding $PROJECT_ID \
  --member="user:$USERNAME_2" \
  --role="roles/viewer"[cite: 1]
echo "=== Task 3 completed! Wait about 30-40 seconds and click 'Check my progress' ==="[cite: 1]

# ------------------------------------------------------------------------------
# TASK 4: Add Resource-Specific Storage Object Viewer Role to User 2
# ------------------------------------------------------------------------------
echo "=== Starting Task 4 ==="[cite: 1]
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:$USERNAME_2" \
  --role="roles/storage.objectViewer"[cite: 1]
echo "=== Task 4 completed! You can now click 'Check my progress' ==="[cite: 1]

# Output verification commands for User 2 environment[cite: 1]
echo "-----------------------------------------------------"[cite: 1]
echo "To verify access inside User 2's Cloud Shell, run:"[cite: 1]
echo "gcloud storage ls gs://$BUCKET_NAME"[cite: 1]
echo "-----------------------------------------------------"[cite: 1]
