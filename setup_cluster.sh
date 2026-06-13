#!/bin/bash

# Configuration
export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items.google-compute-default-region)")
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items.google-compute-default-zone)")
export NETWORK_NAME=gke-network
export SUBNET_NAME=gke-subnet

# Setup Network
gcloud compute networks subnets update $SUBNET_NAME --region=$REGION --add-secondary-ranges=pods-range=10.4.0.0/21,services-range=10.8.0.0/20 || true

# Deploy Cluster
gcloud container clusters create my-standard-cluster --location=$ZONE --num-nodes=1 --network=$NETWORK_NAME --subnetwork=$SUBNET_NAME --cluster-secondary-range-name=pods-range --services-secondary-range-name=services-range --enable-ip-alias --enable-network-policy

# Create Pools
gcloud container node-pools create pool-a --cluster=my-standard-cluster --location=$ZONE --num-nodes=1
gcloud container node-pools create pool-b --cluster=my-standard-cluster --location=$ZONE --num-nodes=1

# Remove Default
gcloud container node-pools delete default-pool --cluster=my-standard-cluster --location=$ZONE --quiet
# GKE Network & Security Project

This project automates the creation of a VPC-native GKE cluster, deploys workloads across segregated node pools, and implements network security policies.

## Components
- **Infrastructure**: Custom VPC network with secondary IP ranges.
- **Node Pools**: 
  - `pool-a`: Hosts testing workloads.
  - `pool-b`: Hosts restricted web services.
- **Security**: NetworkPolicy to isolate `pool-b` from unauthorized ingress.

## Quick Start
1. Run the infrastructure setup:
   `./setup_cluster.sh`
2. Deploy the workloads:
   `kubectl apply -f web-b.yaml -f service-b.yaml -f ping-pod-a.yaml`
3. Apply security:
   `kubectl apply -f isolate-pool-b.yaml`

## Verification
- Test connectivity: `kubectl exec -it ping-pod-a -- ping -c 3 service-b`
