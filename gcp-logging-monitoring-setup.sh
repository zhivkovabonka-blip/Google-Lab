#!/bin/bash
# GCP Cross-Project Monitoring & Logging Automation
# Author: student_01

# 1. Сетъп на Проект 1 (Logging & Export)
export PROJECT_ID_1="qwiklabs-gcp-01-ce49935002d1"
gcloud config set project $PROJECT_ID_1

# Създаване на BigQuery Dataset
bq --project_id=$PROJECT_ID_1 mk project_logs

# Създаване на Log Sinks
gcloud logging sinks create vm_logs \
    bigquery.googleapis.com/projects/$PROJECT_ID_1/datasets/project_logs \
    --log-filter='resource.type="gce_instance"'

# Даване на права на Sink-а (Service Account)
export VM_SA=$(gcloud logging sinks describe vm_logs --format='value(writerIdentity)')
gcloud projects add-iam-policy-binding $PROJECT_ID_1 --member=$VM_SA --role='roles/bigquery.dataEditor'

# Генериране на данни и проверка на BigQuery (Критичната стъпка!)
gcloud logging write syslog "Activation Log" --severity=ERROR --monitored-resource-type="gce_instance"
sleep 30
bq query --use_legacy_sql=false "SELECT * FROM \`$PROJECT_ID_1.project_logs.syslog_*\` LIMIT 10"

# 2. Сетъп на Проект 2 (Monitoring Scope & Dashboard)
export PROJECT_ID_2="qwiklabs-gcp-02-11c9c6bd767a"
gcloud config set project $PROJECT_ID_2

# Свързване на Проект 1 към Проект 2
gcloud beta monitoring metrics-scopes projects add \
    locations/global/metricsScopes/$PROJECT_ID_2 \
    --member-project=$PROJECT_ID_1

# Създаване на Monitoring Dashboard през JSON (за избягване на UI бъгове)
cat > dashboard-config.json << EOF
{
  "displayName": "Infrastructure Health Dashboard",
  "gridLayout": {
    "columns": "2",
    "widgets": [
      {
        "title": "CPU Usage (All Projects)",
        "xyChart": {
          "dataSets": [{
            "timeSeriesQuery": {
              "timeSeriesFilter": {
                "filter": "resource.type=\"gce_instance\" metric.type=\"compute.googleapis.com/instance/cpu/usage_time\""
              }
            }
          }]
        }
      }
    ]
  }
}
EOF

gcloud monitoring dashboards create --config-from-file=dashboard-config.json
