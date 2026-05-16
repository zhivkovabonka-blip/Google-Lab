#!/bin/bash

# ==============================================================================
# Script Name: automate_iam_lab.sh
# Description: Automates GCP IAM and Cloud Storage permission lab tasks.
# ==============================================================================

# Text formatting colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== STARTING GCP IAM LAB AUTOMATION ===${NC}\n"

# Verify that essential environment variables are set
if [ -z "$USERNAME_1" ] || [ -z "$USERNAME_2" ] || [ -z "$PROJECT_ID" ]; then
    echo -e "${YELLOW}Error: Please export USERNAME_1, USERNAME_2, and PROJECT_ID in your terminal first!${NC}"
    exit 1
fi

# Set dynamic globally unique bucket name
BUCKET_NAME="bucket-${PROJECT_ID}-iam-test"

# Ensure gcloud targets the correct project environment
gcloud config set project "$PROJECT_ID"

# ------------------------------------------------------------------------------
# TASK 1: Explore IAM Console Roles (Visual Verification)
# ------------------------------------------------------------------------------
echo -e "${GREEN}[Task 1] Fetching active IAM roles for verification...${NC}"
gcloud projects get-iam-policy "$PROJECT_ID" \
    --flatten="bindings[].members" \
    --format='table(bindings.role, bindings.members)' \
    --filter="bindings.members:($USERNAME_1 OR $USERNAME_2)"

echo -e "\n------------------------------------------------------------------------"

# ------------------------------------------------------------------------------
# TASK 2: Prepare a Cloud Storage Bucket & Upload Sample File
# ------------------------------------------------------------------------------
echo -e "${GREEN}[Task 2] Creating Multi-Region Storage Bucket: gs://$BUCKET_NAME ${NC}"
gcloud storage buckets create "gs://$BUCKET_NAME" --location=us

echo -e "${GREEN}[Task 2] Uploading sample.txt asset...${NC}"
echo "This is a sample test file for IAM verification." > sample.txt
gcloud storage cp sample.txt "gs://$BUCKET_NAME/sample.txt"
rm sample.txt

echo -e "${YELLOW}>> Sleeping for 5 seconds to ensure object availability...${NC}"
sleep 5

# ------------------------------------------------------------------------------
# TASK 3: Revoke Project Viewer Access for Username 2
# ------------------------------------------------------------------------------
echo -e "${GREEN}[Task 3] Removing 'roles/viewer' from $USERNAME_2...${NC}"
gcloud projects remove-iam-policy-binding "$PROJECT_ID" \
    --member="user:$USERNAME_2" \
    --role="roles/viewer" > /dev/null

echo -e "${YELLOW}>> IAM changes propagating. Pausing for 45 seconds...${NC}"
sleep 45

# ------------------------------------------------------------------------------
# TASK 4: Grant Fine-Grained Cloud Storage Permissions
# ------------------------------------------------------------------------------
echo -e "${GREEN}[Task 4] Assigning 'roles/storage.objectViewer' to $USERNAME_2...${NC}"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="user:$USERNAME_2" \
    --role="roles/storage.objectViewer" > /dev/null

echo -e "${YELLOW}>> Finalizing permissions propagation (30 seconds)...${NC}"
sleep 30

# ------------------------------------------------------------------------------
# EXECUTION SUMMARY
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}=== AUTOMATION COMPLETE ===${NC}"
echo -e "You can now click all 'Check my progress' checkpoints in the lab console."
echo -e "To verify access via Username 2 CLI, run:"
echo -e "${YELLOW}gsutil ls gs://$BUCKET_NAME${NC}"
