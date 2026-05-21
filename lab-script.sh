#!/bin/bash
# ============================================
# GSP1077: GKE GitOps CI/CD Pipeline with Cloud Build
# Automated Lab Script
# GitHub: zhivkovabonka-blip
# ============================================

export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
export REGION=us-east4
export GITHUB_USERNAME="zhivkovabonka-blip"

echo "=============================================="
echo " GSP1077 - GKE GitOps CI/CD Pipeline"
echo "=============================================="

# TASK 1: Initialize
echo "===== TASK 1: Initialize ====="
gcloud config set compute/region $REGION
gcloud services enable container.googleapis.com cloudbuild.googleapis.com secretmanager.googleapis.com containeranalysis.googleapis.com
gcloud artifacts repositories create my-repository --repository-format=docker --location=$REGION
gcloud container clusters create hello-cloudbuild --num-nodes 1 --region $REGION
echo "✅ Task 1 done"

# TASK 2: GitHub setup
echo "===== TASK 2: Git repos ====="
gh auth login --hostname github.com --web
USER_EMAIL=$(gcloud auth list --filter=status:ACTIVE --format='value(account)')
git config --global user.name "${GITHUB_USERNAME}"
git config --global user.email "${USER_EMAIL}"
cd ~ && rm -rf hello-cloudbuild-app && mkdir hello-cloudbuild-app
gcloud storage cp -r gs://spls/gsp1077/gke-gitops-tutorial-cloudbuild/* hello-cloudbuild-app
cd ~/hello-cloudbuild-app
sed -i "s/us-central1/$REGION/g" cloudbuild.yaml cloudbuild-delivery.yaml cloudbuild-trigger-cd.yaml kubernetes.yaml.tpl
git init && git config credential.helper gcloud.sh
git remote add google "https://${GITHUB_USERNAME}:YOUR_TOKEN@github.com/${GITHUB_USERNAME}/hello-cloudbuild-app"
git branch -m master && git add . && git commit -m "initial commit" && git push google master
echo "✅ Task 2 done"

# TASK 3: Build image
echo "===== TASK 3: Build container image ====="
COMMIT_ID="$(git rev-parse --short=7 HEAD)"
gcloud builds submit --tag="${REGION}-docker.pkg.dev/${PROJECT_ID}/my-repository/hello-cloudbuild:${COMMIT_ID}" .
echo "✅ Task 3 done"

# TASK 4: CI pipeline
echo "===== TASK 4: CI Pipeline ====="
gcloud builds triggers create github --name="hello-cloudbuild" --region="$REGION" --repo-name="hello-cloudbuild-app" --repo-owner="$GITHUB_USERNAME" --branch-pattern=".*" --build-config="cloudbuild.yaml" --service-account="projects/${PROJECT_ID}/serviceAccounts/${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
git add . && git commit -m "Trigger CI" && git push google master
echo "✅ Task 4 done"

# TASK 5: SSH & Secret Manager
echo "===== TASK 5: SSH Keys & Secret Manager ====="
cd ~ && rm -rf workingdir && mkdir workingdir && cd workingdir
ssh-keygen -t rsa -b 4096 -N '' -f id_github -C "${USER_EMAIL}"
echo "⚠️ Download id_github, upload to Secret Manager as 'ssh_key_secret'"
echo "⚠️ Add public key as Deploy Key in GitHub with write access"
read -p "Press ENTER after manual steps..."
rm id_github*
gcloud projects add-iam-policy-binding ${PROJECT_NUMBER} --member=serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com --role=roles/secretmanager.secretAccessor
gcloud projects add-iam-policy-binding ${PROJECT_NUMBER} --member=serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com --role=roles/container.developer
echo "✅ Task 5 done"

# TASK 6: CD pipeline
echo "===== TASK 6: CD Pipeline ====="
cd ~ && rm -rf hello-cloudbuild-env && mkdir hello-cloudbuild-env
gcloud storage cp -r gs://spls/gsp1077/gke-gitops-tutorial-cloudbuild/* hello-cloudbuild-env
cd ~/hello-cloudbuild-env
sed -i "s/us-central1/$REGION/g" cloudbuild.yaml cloudbuild-delivery.yaml cloudbuild-trigger-cd.yaml kubernetes.yaml.tpl
ssh-keyscan -t rsa github.com > known_hosts.github && chmod +x known_hosts.github
git init && git config user.name "${GITHUB_USERNAME}" && git config user.email "${USER_EMAIL}"
git remote add google "https://YOUR_TOKEN@github.com/${GITHUB_USERNAME}/hello-cloudbuild-env"
git branch -m master && git add . && git commit -m "initial commit" && git push google master
git checkout -b production && git checkout -b candidate
git push google production && git push google candidate
echo "✅ Task 6 done"

# TASK 7-8: Test
echo "===== TASK 7-8: Test Pipeline ====="
cd ~/hello-cloudbuild-app
sed -i 's/Hello World/Hello Cloud Build/g' app.py test_app.py
git add app.py test_app.py && git commit -m "Hello Cloud Build" && git push google master
echo "✅ All tasks complete!"
echo "Check: https://console.cloud.google.com/cloud-build/dashboard"
cd ~/hello-cloudbuild-app

# Създай README.md
cat > README.md << 'EOF'
# GKE GitOps CI/CD Pipeline with Cloud Build

## Lab: GSP1077

Automated CI/CD pipeline using Google Kubernetes Engine, Cloud Build, and GitHub.

## Architecture
- **CI Pipeline**: Runs tests → Builds Docker image → Pushes to Artifact Registry
- **CD Pipeline**: Deploys to GKE → Copies manifest to production branch

## Key Learnings
- Always have GitHub token ready before starting
- Use SSH deploy keys for Cloud Build GitHub access
- Check region settings in all YAML files
- Secret Manager + GitHub Deploy Keys = secure pipeline
EOF

# Създай скрипта
cat > lab-script.sh << 'SCRIPTEOF'
#!/bin/bash
# Full automated script for GSP1077
# See README.md for details
echo "GSP1077 Lab Script - Follow instructions in README.md"
SCRIPTEOF

chmod +x lab-script.sh

# Качи в GitHub
git add README.md lab-script.sh
git commit -m "Add lab documentation and script"
git push google master
