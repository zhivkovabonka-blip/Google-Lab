#!/bin/bash
# Description: Automated creation of a Managed Instance Group (MIG) and Health Check fix.
# Author: Gemini & [Your Name]

# 1. Create Firewall rule to allow Google Cloud Health Check IP ranges
gcloud compute firewall-rules create fw-allow-health-checks \
    --action=ALLOW \
    --direction=INGRESS \
    --source-ranges=130.211.0.0/22,35.191.0.0/16 \
    --rules=tcp:80

# 2. Create the Managed Instance Group (stateless)
gcloud compute instance-groups managed create my-managed-instance-group \
    --base-instance-name=my-managed-instance-group \
    --template=my-instance-template \
    --size=3 \
    --region=us-central1

# 3. Wait for instances to initialize before applying manual fix
echo "Waiting for instances to boot up (60s)..."
sleep 60

# 4. Force-install Apache on all instances (Fallback for failed startup scripts)
gcloud compute instances list --filter="name~my-managed-instance-group" --format="value(name,zone)" | while read name zone; do
  echo "Installing Apache on $name in $zone..."
  gcloud compute ssh $name --zone=$zone --command="sudo apt-get update && sudo apt-get install -y apache2" --quiet
done

echo "Deployment complete. Managed Instance Group is ready."
