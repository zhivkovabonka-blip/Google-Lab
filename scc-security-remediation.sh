#!/bin/bash
# =====================================================================================
# Script:      scc-security-remediation.sh
# Description: Automated Security Hardening & SCC Configuration for Google Cloud Platform.
# Author:      Cloud Security Engineer (Qwiklabs Portfolio)
# Date:        2026-05-23
# =====================================================================================

# Exit immediately if a command exits with a non-zero status
set -e

# 1. Initialize Project Variable
echo "[*] Initializing environment..."
export PROJECT_ID=$(gcloud config get-value project)
echo "Active Google Cloud Project: $PROJECT_ID"
echo "--------------------------------------------------------------------------"

# 2. Configure SCC Settings - Enable Flow Logs Detection Module
echo "[*] Step 1: Enabling VPC_FLOW_LOGS_SETTINGS_NOT_RECOMMENDED module in SCC..."
gcloud scc muteconfigs create mute-flowlogs-findings \
    --project="$PROJECT_ID" \
    --description="Mute rule for VPC Flow Logs in test environments" \
    --filter="category=\"FLOW_LOGS_DISABLED\""
echo "[+] Dynamic Mute Rule created successfully."
echo "--------------------------------------------------------------------------"

# 3. Create a New Auto-VPC Network to Test the Mute Rule
echo "[*] Step 2: Creating a new auto-mode VPC network to test the SCC configuration..."
gcloud compute networks create scc-lab-net --subnet-mode=auto
echo "[+] VPC network 'scc-lab-net' created successfully."
echo "--------------------------------------------------------------------------"

# 4. Mitigate High-Severity Vulnerabilities (Firewall Hardening)
echo "[*] Step 3: Hardening default firewall rules to eliminate public SSH/RDP exposure..."

# Restrict default RDP traffic to Identity-Aware Proxy (IAP) range only
echo "    -> Restricting 'default-allow-rdp' (Port 3389) from 0.0.0.0/0 to 35.235.240.0/20..."
gcloud compute firewall-rules update default-allow-rdp \
    --project="$PROJECT_ID" \
    --source-ranges=35.235.240.0/20

# Restrict default SSH traffic to Identity-Aware Proxy (IAP) range only
echo "    -> Restricting 'default-allow-ssh' (Port 22) from 0.0.0.0/0 to 35.235.240.0/20..."
gcloud compute firewall-rules update default-allow-ssh \
    --project="$PROJECT_ID" \
    --source-ranges=35.235.240.0/20

echo "--------------------------------------------------------------------------"
echo "[+] SUCCESS: Security Command Center configuration and network hardening complete!"
README.md
# Google Cloud Security Automation: Security Command Center & Network Hardening

This repository contains an automated solution for configuring Google Cloud Security Command Center (SCC) and remediating high-severity network vulnerabilities. It streamlines infrastructure security assessment, policy creation, and firewall mitigation.

## Scenario Overview
Based on a digital transformation use case for **Cymbal Bank**, the objective is to centralize security monitoring, filter out noise using automated compliance scopes, and close severe external access holes found in default network deployments.

## Architecture & Logic Implemented
* **Noise Reduction (Dynamic Muting):** Suppresses `FLOW_LOGS_DISABLED` alerts using automated, programmatic policies at the project level.
* **Vulnerability Remediation:** Eliminates open public exposure (`0.0.0.0/0`) on critical administrative ports (22 and 3389) by locking them down to Google's secure **Identity-Aware Proxy (IAP)** IP range (`35.235.240.0/20`).

## Repository Structure
* `scc-security-remediation.sh` — Core shell script containing the `gcloud` infrastructure-as-code automation.

## Prerequisites
* A Google Cloud Platform account with an active project.
* Google Cloud SDK (`gcloud` CLI) installed and authenticated, or execution via Cloud Shell.
* Security Command Center Premium/Enterprise tier privileges assigned.

## Usage

1. Clone this repository:
```bash
   git clone [https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git](https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git)
   cd YOUR_REPO_NAME
