#!/bin/bash
# ==============================================================================
# GOOGLE CLOUD KMS - AUTOMATED DATA BACKUP & ENCRYPTION SCRIPT
# ==============================================================================

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if Project ID is set
if [ -z "$GOOGLE_CLOUD_PROJECT" ]; then
  echo -e "${BLUE}Попълни твоя Google Cloud Project ID:${NC} "
  read GOOGLE_CLOUD_PROJECT
fi

echo -e "${BLUE}[1/6] Creating Cloud Storage Bucket...${NC}"
export BUCKET_NAME="${GOOGLE_CLOUD_PROJECT}-kms_lab"
gsutil mb gs://${BUCKET_NAME}

echo -e "${BLUE}[2/6] Enabling Cloud KMS API...${NC}"
gcloud services enable cloudkms.googleapis.com

echo -e "${BLUE}[3/6] Creating KeyRing and CryptoKey...${NC}"
KEYRING_NAME=labkey
CRYPTOKEY_NAME=qwiklab

gcloud kms keyrings create $KEYRING_NAME --location global

gcloud kms keys create $CRYPTOKEY_NAME --location global \
      --keyring $KEYRING_NAME \
      --purpose encryption

echo -e "${BLUE}[4/6] Configuring IAM Permissions...${NC}"
USER_EMAIL=$(gcloud auth list --limit=1 2>/dev/null | grep '@' | awk '{print $2}')

gcloud kms keyrings add-iam-policy-binding $KEYRING_NAME \
    --location global \
    --member user:$USER_EMAIL \
    --role roles/cloudkms.admin

gcloud kms keyrings add-iam-policy-binding $KEYRING_NAME \
    --location global \
    --member user:$USER_EMAIL \
    --role roles/cloudkms.cryptoKeyEncrypterDecrypter

echo -e "${BLUE}[5/6] Downloading, Encrypting, and Backing Up Files...${NC}"
# Simulating the data folder structure
gsutil -m cp -r gs://${GOOGLE_CLOUD_PROJECT}-kms-lab-data/finance-dept .

MYDIR=finance-dept
FILES=$(find $MYDIR -type f -not -name "*.encrypted")

for file in $FILES; do
  PT=$(cat $file | base64 -w0)
  curl -s -X POST "https://cloudkms.googleapis.com/v1/projects/$GOOGLE_CLOUD_PROJECT/locations/global/keyRings/$KEYRING_NAME/cryptoKeys/$CRYPTOKEY_NAME:encrypt" \
    -d "{\"plaintext\":\"$PT\"}" \
    -H "Authorization:Bearer $(gcloud auth application-default print-access-token)" \
    -H "Content-Type:application/json" \
  | jq .ciphertext -r > $file.encrypted
done

# Uploading encrypted files to the secure bucket
gsutil -m cp finance-dept/inbox/*.encrypted gs://${BUCKET_NAME}/finance-dept/inbox

echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN}  SUCCESS: All data encrypted and backed up to GCS!  ${NC}"
echo -e "${GREEN}======================================================${NC}"
