#!/bin/bash
# GCP VPC Flow Logs Lab — Full Automation
# Lab: Analyzing Network Traffic with VPC Flow Logs
# https://cloud.google.com/vpc/docs/using-flow-logs

set -e

# ─── CONFIG ───────────────────────────────────────────────────────────────────
PROJECT_ID="qwiklabs-gcp-03-0d1d27e8589a"
REGION="europe-west4"
ZONE="europe-west4-a"
NETWORK="vpc-net"
SUBNET="vpc-subnet"
SUBNET_RANGE="10.1.3.0/24"
FIREWALL_RULE="allow-http-ssh"
VM_NAME="web-server"
BQ_DATASET="bq_vpcflows"
SINK_NAME="bq_vpcflows"
LOGGING_SA="service-1019803055901@gcp-sa-logging.iam.gserviceaccount.com"
# ──────────────────────────────────────────────────────────────────────────────

echo "=== Task 1: Configure custom network with VPC flow logs ==="

gcloud compute networks create $NETWORK \
  --project=$PROJECT_ID \
  --subnet-mode=custom

gcloud compute networks subnets create $SUBNET \
  --project=$PROJECT_ID \
  --network=$NETWORK \
  --region=$REGION \
  --range=$SUBNET_RANGE \
  --enable-flow-logs

gcloud compute firewall-rules create $FIREWALL_RULE \
  --project=$PROJECT_ID \
  --network=$NETWORK \
  --action=ALLOW \
  --target-tags=http-server \
  --source-ranges=0.0.0.0/0 \
  --rules=tcp:80,tcp:22

echo "=== Task 2: Create Apache web server ==="

gcloud compute instances create $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --machine-type=e2-micro \
  --network-interface=network=$NETWORK,subnet=$SUBNET \
  --tags=http-server \
  --image-family=debian-11 \
  --image-project=debian-cloud

echo "Waiting 30s for VM to boot..."
sleep 30

gcloud compute ssh $VM_NAME \
  --zone=$ZONE \
  --project=$PROJECT_ID \
  --command="sudo apt-get update -y && \
    sudo apt-get install apache2 -y && \
    echo '<!doctype html><html><body><h1>Hello World!</h1></body></html>' | \
    sudo tee /var/www/html/index.html"

echo "=== Task 3: Verify network traffic is logged ==="

EXT_IP=$(gcloud compute instances describe $VM_NAME \
  --zone=$ZONE \
  --project=$PROJECT_ID \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

echo "External IP: $EXT_IP"

for i in {1..10}; do curl -s "http://$EXT_IP" > /dev/null; done
echo "Traffic generated (10 requests)"

echo "Waiting 2 min for logs to appear..."
sleep 120

gcloud logging read \
  'resource.type="gce_subnetwork" AND logName:"vpc_flows"' \
  --project=$PROJECT_ID \
  --limit=5 \
  --format=json

echo "=== Task 4: Export network traffic to BigQuery ==="

gcloud logging sinks create $SINK_NAME \
  bigquery.googleapis.com/projects/$PROJECT_ID/datasets/$BQ_DATASET \
  --project=$PROJECT_ID \
  --log-filter='resource.type="gce_subnetwork" AND logName:"vpc_flows"'

bq --project_id=$PROJECT_ID mk \
  --dataset \
  --location=EU \
  $BQ_DATASET

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$LOGGING_SA" \
  --role='roles/bigquery.dataEditor'

export MY_SERVER=$EXT_IP
for ((i=1;i<=50;i++)); do curl -s $MY_SERVER > /dev/null; done
echo "Traffic generated (50 requests)"

echo "Waiting 3 min for BigQuery table to populate..."
sleep 180

TABLE_ID=$(bq ls --project_id=$PROJECT_ID $BQ_DATASET \
  --format=json | python3 -c "import sys,json; tables=json.load(sys.stdin); print(tables[0]['tableReference']['tableId'])" 2>/dev/null || echo "")

if [ -n "$TABLE_ID" ]; then
  echo "Table found: $TABLE_ID"
  bq query --use_legacy_sql=false "
SELECT
  SUM(CAST(jsonPayload.bytes_sent AS INT64)) AS bytes,
  jsonPayload.connection.src_ip,
  jsonPayload.connection.src_port,
  jsonPayload.connection.dest_ip,
  jsonPayload.connection.dest_port,
  jsonPayload.connection.protocol
FROM \`$PROJECT_ID.$BQ_DATASET.$TABLE_ID\`
GROUP BY
  jsonPayload.connection.src_ip,
  jsonPayload.connection.src_port,
  jsonPayload.connection.dest_ip,
  jsonPayload.connection.dest_port,
  jsonPayload.connection.protocol
ORDER BY bytes DESC
LIMIT 15"
else
  echo "Table not yet available — run bq ls $BQ_DATASET manually in a few minutes"
fi

echo "=== Task 5: Add VPC flow log aggregation ==="

gcloud compute networks subnets update $SUBNET \
  --region=$REGION \
  --project=$PROJECT_ID \
  --logging-aggregation-interval=interval-30-sec \
  --logging-flow-sampling=0.25 \
  --logging-metadata=include-all

echo "=== All tasks complete ==="
