#!/bin/bash
# ========================================================================================
# Script: gcp_iam_bigquery_lab.sh
# Description: Full automation for Task 1 and Task 2 of the Service Accounts Lab.
# ========================================================================================

# [DYNAMIC VARIABLES]
PROJECT_ID=$(gcloud config get-value project)
ZONE="us-east4-b"
SA_TASK1="my-sa-123"
SA_TASK2="bigquery-qwiklab"
VM_NAME="bigquery-instance"

echo "--------------------------------------------------------"
echo "STARTING FULL LAB AUTOMATION (PROJECT: $PROJECT_ID)"
echo "--------------------------------------------------------"

# --- TASK 1: GENERAL SERVICE ACCOUNT SETUP ---
echo "[TASK 1] Creating Service Account: $SA_TASK1"
gcloud iam service-accounts create $SA_TASK1 --display-name="Editor SA" --quiet || true

echo "[TASK 1] Granting Editor Role..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_TASK1@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/editor" --quiet

# --- TASK 2: BIGQUERY & COMPUTE ENGINE ---
echo "[TASK 2] Creating Service Account: $SA_TASK2"
gcloud iam service-accounts create $SA_TASK2 --display-name="BigQuery SA" --quiet || true

echo "[TASK 2] Assigning Granular BigQuery Roles..."
for ROLE in roles/bigquery.dataViewer roles/bigquery.user; do
  gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member="serviceAccount:$SA_TASK2@$PROJECT_ID.iam.gserviceaccount.com" \
      --role="$ROLE" --quiet
done

echo "[TASK 2] Provisioning VM Instance with Shielded Security..."
gcloud compute instances create $VM_NAME \
    --zone=$ZONE \
    --machine-type=e2-standard-2 \
    --image-family=debian-12 \
    --image-project=debian-cloud \
    --service-account="$SA_TASK2@$PROJECT_ID.iam.gserviceaccount.com" \
    --scopes=https://www.googleapis.com/auth/cloud-platform \
    --shielded-secure-boot \
    --quiet

echo "Waiting for VM initialization (30s)..."
sleep 30

echo "[TASK 2] Running Remote BigQuery Query via SSH..."
gcloud compute ssh $VM_NAME --zone=$ZONE --project=$PROJECT_ID --command="
    sudo apt-get update -y && sudo apt-get install -y python3-pip python3.11-venv
    python3 -m venv bq_venv && source bq_venv/bin/activate
    pip3 install --upgrade pip
    pip3 install google-cloud-bigquery pandas pyarrow db-dtypes
    
    cat <<EOF > query.py
from google.cloud import bigquery
client = bigquery.Client(project='$PROJECT_ID')
query = 'SELECT year, COUNT(1) as num_babies FROM publicdata.samples.natality WHERE year > 2000 GROUP BY year'
print(client.query(query).to_dataframe())
EOF
    python3 query.py
"

echo "--------------------------------------------------------"
echo "LAB COMPLETE: ALL TASKS FINISHED SUCCESSFULLY!"
echo "--------------------------------------------------------"
