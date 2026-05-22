#!/bin/bash

# Script to configure RBAC permissions in a GKE cluster
# This script automates the process of granting cluster-admin rights

CLUSTER_NAME="simplecluster"
ZONE="us-east4-c"
USER_EMAIL=$(gcloud config list account --format 'value(core.account)')

echo "Configuring cluster-admin access for: $USER_EMAIL"

# Fetching cluster credentials
gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE

# Creating the ClusterRoleBinding
kubectl create clusterrolebinding clusteradmin \
  --clusterrole=cluster-admin \
  --user="$USER_EMAIL"

echo "Success: Cluster-admin rights have been granted."
./gke-rbac-fix.sh
