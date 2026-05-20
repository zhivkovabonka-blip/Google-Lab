#!/usr/bin/env bash
# ==============================================================================
# cloud_deploy_lab_t4.sh
# Tasks 4-9: Build, pipeline, targets, release, promote, approve
# PROJECT: qwiklabs-gcp-02-8c9b865577e0  |  REGION: europe-west1
# ==============================================================================
set -euo pipefail

export PROJECT_ID="qwiklabs-gcp-02-8c9b865577e0"
export REGION="europe-west1"
export ZONE="europe-west1-b"

log()  { echo -e "\n\033[1;34m[INFO]\033[0m  $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m    $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
die()  { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

wait_for_clusters() {
  log "Waiting for all clusters to reach RUNNING state..."
  local attempts=0
  while true; do
    local not_ready
    not_ready=$(gcloud container clusters list \
      --region "$REGION" \
      --format="csv[no-heading](name,status)" \
      | grep -v ",RUNNING" || true)
    [[ -z "$not_ready" ]] && { ok "All clusters are RUNNING."; break; }
    attempts=$((attempts + 1))
    [[ $attempts -ge 30 ]] && die "Clusters not ready after 15 minutes."
    warn "Not yet ready:\n$not_ready\n  (attempt $attempts/30 – retrying in 30s)"
    sleep 30
  done
}

wait_for_rollout() {
  local target="$1"
  local release="$2"
  log "Waiting for rollout to '$target' (release: $release)..."
  local attempts=0
  while true; do
    local state
    state=$(gcloud beta deploy rollouts list \
      --delivery-pipeline web-app \
      --release "$release" \
      --region "$REGION" \
      --format="csv[no-heading](targetId,state)" \
      | grep "^${target}," | awk -F',' '{print $2}' || true)
    case "$state" in
      SUCCEEDED)        ok "Rollout to '$target' completed successfully."; return 0 ;;
      FAILED)           die "Rollout to '$target' FAILED." ;;
      PENDING_APPROVAL) ok "Rollout to '$target' is awaiting approval."; return 0 ;;
      *) warn "Status '${state:-none}' – retrying in 30s (attempt $((++attempts)))..." ;;
    esac
    [[ $attempts -ge 40 ]] && die "Rollout to '$target' did not complete in time."
    sleep 30
  done
}

# ──────────────────────────────────────────────────────────────────────────────
# TASK 4 – Build and push container images
# ──────────────────────────────────────────────────────────────────────────────
log "Task 4: Enabling Cloud Build API"
gcloud services enable cloudbuild.googleapis.com

log "Task 4: Cloning the tutorial repository"
cd ~/
if [[ ! -d cloud-deploy-tutorials ]]; then
  git clone https://github.com/GoogleCloudPlatform/cloud-deploy-tutorials.git
fi
cd cloud-deploy-tutorials
git checkout c3cae80 --quiet
cd tutorials/base

log "Task 4: Generating skaffold.yaml"
envsubst < clouddeploy-config/skaffold.yaml.template > web/skaffold.yaml

log "Task 4: Creating Cloud Storage bucket for Cloud Build"
BUCKET="gs://${PROJECT_ID}_cloudbuild"
if ! gsutil ls "$BUCKET" &>/dev/null; then
  gsutil mb -p "$PROJECT_ID" "$BUCKET"
  ok "Bucket $BUCKET created."
else
  warn "Bucket $BUCKET already exists."
fi

log "Task 4: Building the application with Skaffold"
cd web
skaffold build --interactive=false \
  --default-repo "$REGION-docker.pkg.dev/$PROJECT_ID/web-app" \
  --file-output artifacts.json
cd ..
ok "Build complete. Images in Artifact Registry:"
gcloud artifacts docker images list \
  "$REGION-docker.pkg.dev/$PROJECT_ID/web-app" \
  --include-tags --format yaml

# ──────────────────────────────────────────────────────────────────────────────
# TASK 5 – Create the delivery pipeline
# ──────────────────────────────────────────────────────────────────────────────
log "Task 5: Configuring the delivery pipeline"
gcloud config set deploy/region "$REGION"
cp clouddeploy-config/delivery-pipeline.yaml.template \
   clouddeploy-config/delivery-pipeline.yaml

gcloud beta deploy apply \
  --file=clouddeploy-config/delivery-pipeline.yaml \
  --region="$REGION"
ok "Delivery pipeline 'web-app' created."

# ──────────────────────────────────────────────────────────────────────────────
# TASK 6 – Configure deployment targets
# ──────────────────────────────────────────────────────────────────────────────
log "Task 6: Waiting for clusters to be RUNNING"
wait_for_clusters

log "Task 6: Fetching cluster credentials and renaming kubectl contexts"
CONTEXTS=("test" "staging" "prod")
for CONTEXT in "${CONTEXTS[@]}"; do
  gcloud container clusters get-credentials "$CONTEXT" --region "$REGION"
  kubectl config rename-context \
    "gke_${PROJECT_ID}_${REGION}_${CONTEXT}" "$CONTEXT" 2>/dev/null || true
done

log "Task 6: Creating 'web-app' namespace in all three clusters"
for CONTEXT in "${CONTEXTS[@]}"; do
  kubectl --context "$CONTEXT" apply -f kubernetes-config/web-app-namespace.yaml
done

log "Task 6: Creating deployment targets"
for CONTEXT in "${CONTEXTS[@]}"; do
  envsubst < "clouddeploy-config/target-${CONTEXT}.yaml.template" \
            > "clouddeploy-config/target-${CONTEXT}.yaml"
  gcloud beta deploy apply \
    --file "clouddeploy-config/target-${CONTEXT}.yaml" \
    --region="$REGION"
done
ok "Targets test / staging / prod created."

# ──────────────────────────────────────────────────────────────────────────────
# TASK 7 – Create a release (deploys to test automatically)
# ──────────────────────────────────────────────────────────────────────────────
RELEASE="web-app-001"
log "Task 7: Creating release '$RELEASE'"
if gcloud beta deploy releases describe "$RELEASE" \
     --delivery-pipeline web-app --region "$REGION" &>/dev/null; then
  warn "Release '$RELEASE' already exists – skipping."
else
  gcloud beta deploy releases create "$RELEASE" \
    --delivery-pipeline web-app \
    --build-artifacts web/artifacts.json \
    --source web/ \
    --region "$REGION"
fi

wait_for_rollout "test" "$RELEASE"

log "Task 7: Verifying deployment in the test cluster"
kubectl config use-context test
kubectl get all -n web-app

# ──────────────────────────────────────────────────────────────────────────────
# TASK 8 – Promote to staging
# ──────────────────────────────────────────────────────────────────────────────
log "Task 8: Promoting to staging"
gcloud beta deploy releases promote \
  --delivery-pipeline web-app \
  --release "$RELEASE" \
  --region "$REGION" \
  --quiet

wait_for_rollout "staging" "$RELEASE"

# ──────────────────────────────────────────────────────────────────────────────
# TASK 9 – Promote to prod and approve
# ──────────────────────────────────────────────────────────────────────────────
log "Task 9: Promoting to prod"
gcloud beta deploy releases promote \
  --delivery-pipeline web-app \
  --release "$RELEASE" \
  --region "$REGION" \
  --quiet

log "Task 9: Waiting for rollout to reach PENDING_APPROVAL..."
wait_for_rollout "prod" "$RELEASE"

log "Task 9: Approving the prod rollout"
ROLLOUT_NAME="${RELEASE}-to-prod-0001"
gcloud beta deploy rollouts approve "$ROLLOUT_NAME" \
  --delivery-pipeline web-app \
  --release "$RELEASE" \
  --region "$REGION" \
  --quiet

wait_for_rollout "prod" "$RELEASE"

log "Task 9: Verifying deployment in the prod cluster"
kubectl config use-context prod
kubectl get all -n web-app

ok "══════════════════════════════════════════════════════"
ok " Lab completed successfully!"
ok " Pipeline: test → staging → prod (approved)"
ok "══════════════════════════════════════════════════════"
