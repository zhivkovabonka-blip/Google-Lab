#!/bin/bash
# ==============================================================================
# Google Cloud IAM Custom Roles - Full Automation Script
# ==============================================================================
set -e

# Auto-detect Project ID from GCP Environment
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ] || [ "$PROJECT_ID" = "(unset)" ]; then
    PROJECT_ID=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/project/project-id 2>/dev/null)
fi

if [ -z "$PROJECT_ID" ]; then
    echo "ERROR: Could not detect GCP Project ID. Please run 'gcloud config set project [PROJECT_ID]' first."
    exit 1
fi

echo "======================================================================"
echo "Starting IAM Automation for Project: $PROJECT_ID"
echo "======================================================================"

# Tasks 1-3: Exploration
echo -e "\n[Tasks 1-3] Viewing available permissions and metadata..."
gcloud iam list-testable-permissions //cloudresourcemanager.googleapis.com/projects/$PROJECT_ID --limit=5
gcloud iam roles describe roles/viewer
gcloud iam list-grantable-roles //cloudresourcemanager.googleapis.com/projects/$PROJECT_ID --limit=5

# Task 4: Create Custom Roles
echo -e "\n[Task 4a] Creating 'editor' custom role via YAML..."
cat <<EOF > role-definition.yaml
title: "Role Editor"
description: "Edit access for App Versions"
stage: "ALPHA"
includedPermissions:
- appengine.versions.create
- appengine.versions.delete
EOF
gcloud iam roles create editor --project=$PROJECT_ID --file=role-definition.yaml

echo -e "\n[Task 4b] Creating 'viewer' custom role via Flags..."
gcloud iam roles create viewer --project=$PROJECT_ID \
    --title="Role Viewer" \
    --description="Custom role description." \
    --permissions="compute.instances.get,compute.instances.list" \
    --stage=ALPHA

# Task 5: List Custom Roles
echo -e "\n[Task 5] Listing custom roles..."
gcloud iam roles list --project=$PROJECT_ID

# Task 6: Update Custom Roles
echo -e "\n[Task 6a] Updating 'editor' role via YAML (Fetching current ETAG)..."
CURRENT_ETAG=$(gcloud iam roles describe editor --project=$PROJECT_ID --format="value(etag)")
cat <<EOF > new-role-definition.yaml
description: Edit access for App Versions
etag: $CURRENT_ETAG
includedPermissions:
- appengine.versions.create
- appengine.versions.delete
- storage.buckets.get
- storage.buckets.list
name: projects/$PROJECT_ID/roles/editor
stage: ALPHA
title: Role Editor
EOF
gcloud iam roles update editor --project=$PROJECT_ID --file=new-role-definition.yaml

echo -e "\n[Task 6b] Updating 'viewer' role via Flags..."
gcloud iam roles update viewer --project=$PROJECT_ID \
    --add-permissions="storage.buckets.get,storage.buckets.list"

# Task 7: Disable Custom Role
echo -e "\n[Task 7] Disabling 'viewer' role..."
gcloud iam roles update viewer --project=$PROJECT_ID --stage=DISABLED

# Task 8: Delete Custom Role
echo -e "\n[Task 8] Deleting 'viewer' role..."
gcloud iam roles delete viewer --project=$PROJECT_ID --quiet

# Task 9: Restore Custom Role
echo -e "\n[Task 9] Restoring 'viewer' role..."
gcloud iam roles undelete viewer --project=$PROJECT_ID

echo -e "\n======================================================================"
echo "IAM Custom Roles Automation completed successfully!"
echo "======================================================================"
