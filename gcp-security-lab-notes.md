Mute1 · SH
#!/bin/bash
# Mute rule 1: Flow Logs
 
gcloud scc muteconfigs create muting-flow-log-findings \
    --project=qwiklabs-gcp-00-e74c8e12b6f9 \
    --description="Rule for muting VPC Flow Logs" \
    --filter='category="FLOW_LOGS_DISABLED"'
 
echo "✓ muting-flow-log-findings created"
Mute2 · SH
#!/bin/bash
# Mute rule 2: Audit Logging
 
gcloud scc muteconfigs create muting-audit-logging-findings \
    --project=qwiklabs-gcp-00-e74c8e12b6f9 \
    --description="Rule for muting audit logs" \
    --filter='category="AUDIT_LOGGING_DISABLED"'
 
echo "✓ muting-audit-logging-findings created"
Mute3 · SH
#!/bin/bash
# Mute rule 3: Admin Service Account
 
gcloud scc muteconfigs create muting-admin-sa-findings \
    --project=qwiklabs-gcp-00-e74c8e12b6f9 \
    --description="Rule for muting admin service account findings" \
    --filter='category="ADMIN_SERVICE_ACCOUNT"'
 
echo "✓ muting-admin-sa-findings created"

  # GCP Security Lab – Cymbal Bank (Qwiklabs)

## Overview
This lab focused on using Google Cloud Security Command Center (SCC) to identify and fix security vulnerabilities in a cloud environment.

## Key Tasks Completed

### 1. Fixed High Severity Findings
- Identified open SSH (port 22) and RDP (port 3389) firewall rules
- Restricted access from public internet
- Updated source ranges to: `35.235.240.0/20`

### 2. Secured Compute Engine VM
- Reserved a static external IP for the VM instance
- Ensured stable access for security scanning tools

### 3. Web Security Scanner
- Configured and executed a web application scan
- Target application running on port `8080`
- Identified application-level vulnerabilities

### 4. Exported SCC Findings
- Created a Cloud Storage bucket:
  `scc-export-bucket-qwiklabs-gcp-00-e74c8e12b6f9`
- Exported findings in JSONL format for audit purposes
- Stored file: `findings.jsonl`

## Bucket Used

## Key Learnings
- How to use SCC for vulnerability detection
- How to remediate firewall misconfigurations
- How to secure VM access with static IPs
- How to export security findings for compliance

## Conclusion
This lab demonstrated practical cloud security operations including detection, mitigation, and reporting of security issues in Google Cloud Platform.
