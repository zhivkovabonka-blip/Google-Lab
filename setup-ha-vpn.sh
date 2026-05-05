#!/bin/bash
# Google Cloud Platform - HA VPN Automation Script
# Author: Gemini Assistant & Student

set -e # 

echo "🚀 Starting HA VPN Deployment..."

# --- Configuration ---
REGION="us-central1"
REGION_REMOTE="us-west1"
ZONE_DEMO_1="us-central1-f"
ZONE_DEMO_2="us-west1-a"
ZONE_ONPREM="us-central1-a"
SHARED_SECRET=$(openssl rand -base64 24)

# 1. Network Creation
echo "🌐 Creating VPC networks..."
gcloud compute networks create vpc-demo --subnet-mode custom
gcloud compute networks create on-prem --subnet-mode custom

# 2. Subnets
echo "📍 Creating subnets..."
gcloud compute networks subnets create vpc-demo-subnet1 --network vpc-demo --range 10.1.1.0/24 --region $REGION
gcloud compute networks subnets create vpc-demo-subnet2 --network vpc-demo --range 10.2.1.0/24 --region $REGION_REMOTE
gcloud compute networks subnets create on-prem-subnet1 --network on-prem --range 192.168.1.0/24 --region $REGION

# 3. Firewalls
echo "🛡️ Configuring firewall rules..."
gcloud compute firewall-rules create vpc-demo-allow-ssh-icmp --network vpc-demo --allow tcp:22,icmp
gcloud compute firewall-rules create on-prem-allow-ssh-icmp --network on-prem --allow tcp:22,icmp
gcloud compute firewall-rules create vpc-demo-allow-subnets-from-on-prem --network vpc-demo --allow tcp,udp,icmp --source-ranges 192.168.1.0/24
gcloud compute firewall-rules create on-prem-allow-subnets-from-vpc-demo --network on-prem --allow tcp,udp,icmp --source-ranges 10.1.1.0/24,10.2.1.0/24

# 4. Compute Instances
echo "🖥️ Creating VM instances..."
gcloud compute instances create vpc-demo-instance1 --machine-type=e2-medium --zone $ZONE_DEMO_1 --subnet vpc-demo-subnet1
gcloud compute instances create vpc-demo-instance2 --machine-type=e2-medium --zone $ZONE_DEMO_2 --subnet vpc-demo-subnet2
gcloud compute instances create on-prem-instance1 --machine-type=e2-medium --zone $ZONE_ONPREM --subnet on-prem-subnet1

# 5. VPN Infrastructure
echo "☁️ Setting up HA VPN Gateways and Cloud Routers..."
gcloud compute vpn-gateways create vpc-demo-vpn-gw1 --network vpc-demo --region $REGION
gcloud compute vpn-gateways create on-prem-vpn-gw1 --network on-prem --region $REGION

gcloud compute routers create vpc-demo-router1 --region $REGION --network vpc-demo --asn 65001
gcloud compute routers create on-prem-router1 --region $REGION --network on-prem --asn 65002

# 6. Tunnels and BGP Sessions
echo "🔗 Establishing VPN Tunnels and BGP Peering..."
for i in 0 1; do
  # Tunnels for vpc-demo
  gcloud compute vpn-tunnels create vpc-demo-tunnel$i \
      --peer-gcp-gateway on-prem-vpn-gw1 --region $REGION --ike-version 2 \
      --shared-secret $SHARED_SECRET --router vpc-demo-router1 --vpn-gateway vpc-demo-vpn-gw1 --interface $i

  # Tunnels for on-prem
  gcloud compute vpn-tunnels create on-prem-tunnel$i \
      --peer-gcp-gateway vpc-demo-vpn-gw1 --region $REGION --ike-version 2 \
      --shared-secret $SHARED_SECRET --router on-prem-router1 --vpn-gateway on-prem-vpn-gw1 --interface $i
done

# BGP Configuration (Tunnel 0)
gcloud compute routers add-interface vpc-demo-router1 --interface-name if-t0 --ip-address 169.254.0.1 --mask-length 30 --vpn-tunnel vpc-demo-tunnel0 --region $REGION
gcloud compute routers add-bgp-peer vpc-demo-router1 --peer-name bgp-t0 --interface if-t0 --peer-ip-address 169.254.0.2 --peer-asn 65002 --region $REGION

gcloud compute routers add-interface on-prem-router1 --interface-name if-t0 --ip-address 169.254.0.2 --mask-length 30 --vpn-tunnel on-prem-tunnel0 --region $REGION
gcloud compute routers add-bgp-peer on-prem-router1 --peer-name bgp-t0 --interface if-t0 --peer-ip-address 169.254.0.1 --peer-asn 65001 --region $REGION

# BGP Configuration (Tunnel 1)
gcloud compute routers add-interface vpc-demo-router1 --interface-name if-t1 --ip-address 169.254.1.1 --mask-length 30 --vpn-tunnel vpc-demo-tunnel1 --region $REGION
gcloud compute routers add-bgp-peer vpc-demo-router1 --peer-name bgp-t1 --interface if-t1 --peer-ip-address 169.254.1.2 --peer-asn 65002 --region $REGION

gcloud compute routers add-interface on-prem-router1 --interface-name if-t1 --ip-address 169.254.1.2 --mask-length 30 --vpn-tunnel on-prem-tunnel1 --region $REGION
gcloud compute routers add-bgp-peer on-prem-router1 --peer-name bgp-t1 --interface if-t1 --peer-ip-address 169.254.1.1 --peer-asn 65001 --region $REGION

# 7. Enable Global Routing
echo "🌍 Enabling Global Dynamic Routing..."
gcloud compute networks update vpc-demo --bgp-routing-mode GLOBAL

echo "✅ Infrastructure Deployed Successfully!"
