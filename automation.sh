#!/bin/bash

# ========================================================================================
# Google Cloud BigQuery Security Lab Automation
# Description: Automates Task 1 to Task 4 including Authorized Views and ACL setup.
# Author: Your Name/GitHub
# ========================================================================================

# 1. Сетване на променливи
PROJECT_ID=$(gcloud config get-value project)
# ВАЖНО: Замени този имейл с актуалния User 2 от твоя лаб
USER2_EMAIL="student-01-f135f3a342dc@qwiklabs.net"

echo "🚀 Starting Automation for Project: $PROJECT_ID..."

# ----------------------------------------------------------------------------------------
# TASK 1: Create Source Dataset & Load Data
# ----------------------------------------------------------------------------------------
echo "📦 Creating source_data dataset..."
bq mk --location=US source_data

echo "📥 Loading source data from Cloud Storage..."
bq load --location=US --autodetect --source_format=CSV \
source_data.events gs://cloud-training/gcpsec/labs/bq-authviews-source.csv

echo "✏️ Updating email records for User 2 simulation..."
bq query --use_legacy_sql=false \
"UPDATE \`$PROJECT_ID.source_data.events\` 
SET email='$USER2_EMAIL' 
WHERE email='rhonda.burns@example-dev.com'"

# ----------------------------------------------------------------------------------------
# TASK 2: Create Analyst Dataset & Views
# ----------------------------------------------------------------------------------------
echo "📊 Creating analyst_views dataset..."
bq mk --location=US analyst_views

echo "🖼️ Creating Redacted View (no_user_info)..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE VIEW \`$PROJECT_ID.analyst_views.no_user_info\` AS
SELECT
  date, type, company, call_duration, call_type, call_num_users,
  call_os, rating, comment, session_id, dialin_duration,
  ticket_number, ticket_driver
FROM
  \`$PROJECT_ID.source_data.events\`"

echo "🔐 Creating Row-Filtered View (row_filter_session_user)..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE VIEW \`$PROJECT_ID.analyst_views.row_filter_session_user\` AS
SELECT * FROM \`$PROJECT_ID.source_data.events\` 
WHERE email = SESSION_USER()"

# ----------------------------------------------------------------------------------------
# TASK 3 & 4: Secure Datasets & Authorize Views (ACL)
# ----------------------------------------------------------------------------------------
echo "🔑 Granting Data Viewer role to User 2 on analyst_views..."
bq add-iam-policy-binding \
  --member="user:$USER2_EMAIL" \
  --role="roles/bigquery.dataViewer" \
  $PROJECT_ID:analyst_views

echo "🛡️ Configuring Authorized Views on source_data using JSON ACL..."
cat > /tmp/source_data_acl.json <<EOF
{
  "access": [
    {"role": "OWNER", "specialGroup": "projectOwners"},
    {"role": "WRITER", "specialGroup": "projectWriters"},
    {"role": "READER", "specialGroup": "projectReaders"},
    {
      "view": {
        "projectId": "$PROJECT_ID",
        "datasetId": "analyst_views",
        "tableId": "no_user_info"
      }
    },
    {
      "view": {
        "projectId": "$PROJECT_ID",
        "datasetId": "analyst_views",
        "tableId": "row_filter_session_user"
      }
    }
  ]
}
EOF

# Прилагане на правата върху изходния датасет
bq update --source /tmp/source_data_acl.json $PROJECT_ID:source_data

echo "✅ Done! Click 'Check my progress' now."
