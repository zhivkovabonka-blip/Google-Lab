#!/bin/bash
# =============================================================
# GCP Cloud Audit Logs Lab - Full Automation Script
# Lab: Cloud Audit Logs / Log Exports to BigQuery
# =============================================================

set -e

PROJECT_ID=$(gcloud config get-value project)
echo ">>> Project: $PROJECT_ID"

# -------------------------------------------------------
# TASK 1: Enable Data Access Audit Logs
# -------------------------------------------------------
echo ">>> [Task 1] Fetching IAM policy..."
gcloud projects get-iam-policy $PROJECT_ID --format=json > ./policy.json

echo ">>> [Task 1] Injecting auditConfigs into policy.json..."
python3 - <<'EOF'
import json

with open("policy.json", "r") as f:
    policy = json.load(f)

policy["auditConfigs"] = [
    {
        "service": "allServices",
        "auditLogConfigs": [
            {"logType": "ADMIN_READ"},
            {"logType": "DATA_READ"},
            {"logType": "DATA_WRITE"}
        ]
    }
]

with open("policy.json", "w") as f:
    json.dump(policy, f, indent=2)

print("auditConfigs injected successfully.")
EOF

echo ">>> [Task 1] Setting updated IAM policy..."
gcloud projects set-iam-policy $PROJECT_ID ./policy.json

# -------------------------------------------------------
# TASK 2: Generate Account Activity
# -------------------------------------------------------
echo ">>> [Task 2] Creating storage bucket and uploading file..."
gcloud storage buckets create gs://$PROJECT_ID 2>/dev/null || echo "Bucket already exists, skipping."
echo "this is a sample file" > sample.txt
gcloud storage cp sample.txt gs://$PROJECT_ID

echo ">>> [Task 2] Creating network..."
gcloud compute networks create mynetwork --subnet-mode=auto 2>/dev/null || echo "Network already exists, skipping."

echo ">>> [Task 2] Creating VM instance..."
gcloud compute instances create default-us-vm \
  --machine-type=e2-micro \
  --zone=europe-west1-b \
  --network=mynetwork -q 2>/dev/null || echo "VM already exists or zone exhausted, skipping."

echo ">>> [Task 2] Deleting storage bucket..."
gcloud storage rm -r gs://$PROJECT_ID 2>/dev/null || true

# -------------------------------------------------------
# TASK 4: Export Setup - Create BigQuery Sink
# -------------------------------------------------------
echo ">>> [Task 4] Creating BigQuery dataset for audit logs..."
bq mk --dataset ${PROJECT_ID}:auditlogs_dataset 2>/dev/null || echo "Dataset already exists, skipping."

echo ">>> [Task 4] Creating log sink AuditLogsExport..."
gcloud logging sinks create AuditLogsExport \
  bigquery.googleapis.com/projects/$PROJECT_ID/datasets/auditlogs_dataset \
  --log-filter="logName=\"projects/$PROJECT_ID/logs/cloudaudit.googleapis.com%2Factivity\"" \
  2>/dev/null || echo "Sink already exists, skipping."

# -------------------------------------------------------
# TASK 4: Generate More Activity (post-sink)
# -------------------------------------------------------
echo ">>> [Task 4] Generating activity after sink creation..."

gcloud storage buckets create gs://$PROJECT_ID 2>/dev/null || true
gcloud storage buckets create gs://${PROJECT_ID}-test 2>/dev/null || true
echo "this is another sample file" > sample2.txt
gcloud storage cp sample.txt gs://${PROJECT_ID}-test 2>/dev/null || true

echo ">>> [Task 4] Deleting VM..."
gcloud compute instances delete --zone=europe-west1-b --delete-disks=all default-us-vm -q 2>/dev/null || true

echo ">>> [Task 4] Deleting buckets..."
gcloud storage rm -r gs://$PROJECT_ID 2>/dev/null || true
gcloud storage rm -r gs://${PROJECT_ID}-test 2>/dev/null || true

# -------------------------------------------------------
# TASK 5: Generate More Activity + BigQuery Queries
# -------------------------------------------------------
echo ">>> [Task 5] Generating more activity for BigQuery analysis..."

gcloud compute instances create default-us-vm \
  --zone=europe-west1-b --machine-type=e2-micro --network=mynetwork -q 2>/dev/null || true

gcloud compute instances delete --zone=europe-west1-b --delete-disks=all default-us-vm -q 2>/dev/null || true

gcloud storage buckets create gs://$PROJECT_ID 2>/dev/null || true
gcloud storage buckets create gs://${PROJECT_ID}-test 2>/dev/null || true
gcloud storage rm -r gs://$PROJECT_ID 2>/dev/null || true
gcloud storage rm -r gs://${PROJECT_ID}-test 2>/dev/null || true

echo ">>> [Task 5] Waiting 60s for logs to propagate to BigQuery..."
sleep 60

echo ">>> [Task 5] Querying VM deletions..."
bq query --use_legacy_sql=false \
'SELECT timestamp, resource.labels.instance_id,
  protopayload_auditlog.authenticationInfo.principalEmail,
  protopayload_auditlog.resourceName,
  protopayload_auditlog.methodName
FROM `auditlogs_dataset.cloudaudit_googleapis_com_activity_*`
WHERE PARSE_DATE("%Y%m%d", _TABLE_SUFFIX)
  BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) AND CURRENT_DATE()
  AND resource.type = "gce_instance"
  AND operation.first IS TRUE
  AND protopayload_auditlog.methodName = "v1.compute.instances.delete"
ORDER BY timestamp, resource.labels.instance_id
LIMIT 1000'

echo ">>> [Task 5] Querying bucket deletions..."
bq query --use_legacy_sql=false \
'SELECT timestamp, resource.labels.bucket_name,
  protopayload_auditlog.authenticationInfo.principalEmail,
  protopayload_auditlog.resourceName,
  protopayload_auditlog.methodName
FROM `auditlogs_dataset.cloudaudit_googleapis_com_activity_*`
WHERE PARSE_DATE("%Y%m%d", _TABLE_SUFFIX)
  BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) AND CURRENT_DATE()
  AND resource.type = "gcs_bucket"
  AND protopayload_auditlog.methodName = "storage.buckets.delete"
ORDER BY timestamp, resource.labels.instance_id
LIMIT 1000'

echo ""
echo "=== LAB COMPLETE ==="
