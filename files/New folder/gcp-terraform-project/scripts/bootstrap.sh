#!/usr/bin/env bash
# =============================================================================
# scripts/bootstrap.sh
#
# Run ONCE before the first `terraform init`.
# Creates the GCS bucket for remote state and uploads the SA key to Vault.
#
# Prerequisites:
#   - gcloud CLI authenticated as a project Owner
#   - vault CLI installed and VAULT_ADDR exported
#   - jq installed
# =============================================================================
set -euo pipefail

PROJECT_ID="cool-plasma-494014-t2"
REGION="asia-south1"
STATE_BUCKET="${PROJECT_ID}-tfstate"
SA_NAME="sa-terraform-bootstrap"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
VAULT_SECRET_PATH="secret/gcp/terraform-sa"

echo "▶ Enabling required GCP APIs..."
gcloud services enable \
  compute.googleapis.com \
  container.googleapis.com \
  storage.googleapis.com \
  pubsub.googleapis.com \
  iam.googleapis.com \
  cloudresourcemanager.googleapis.com \
  secretmanager.googleapis.com \
  vpcaccess.googleapis.com \
  --project="${PROJECT_ID}"

echo "▶ Creating GCS bucket for Terraform state..."
if ! gsutil ls -p "${PROJECT_ID}" "gs://${STATE_BUCKET}" &>/dev/null; then
  gsutil mb \
    -p "${PROJECT_ID}" \
    -l "${REGION}" \
    -b on \
    "gs://${STATE_BUCKET}"
  gsutil versioning set on "gs://${STATE_BUCKET}"
  echo "  Bucket gs://${STATE_BUCKET} created with versioning."
else
  echo "  Bucket gs://${STATE_BUCKET} already exists, skipping."
fi

echo "▶ Creating bootstrap service account..."
if ! gcloud iam service-accounts describe "${SA_EMAIL}" --project="${PROJECT_ID}" &>/dev/null; then
  gcloud iam service-accounts create "${SA_NAME}" \
    --display-name="Terraform Bootstrap SA" \
    --project="${PROJECT_ID}"
fi

echo "▶ Granting roles to bootstrap SA..."
for ROLE in \
  roles/compute.admin \
  roles/container.admin \
  roles/storage.admin \
  roles/pubsub.admin \
  roles/iam.serviceAccountAdmin \
  roles/iam.serviceAccountTokenCreator \
  roles/resourcemanager.projectIamAdmin; do
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="${ROLE}" \
    --quiet
done

echo "▶ Generating SA key..."
KEY_FILE="/tmp/terraform-sa-key.json"
gcloud iam service-accounts keys create "${KEY_FILE}" \
  --iam-account="${SA_EMAIL}" \
  --project="${PROJECT_ID}"

echo "▶ Uploading SA key JSON to Vault at ${VAULT_SECRET_PATH}..."
vault kv put "${VAULT_SECRET_PATH}" \
  key="$(cat ${KEY_FILE})"

echo "▶ Removing local key file..."
rm -f "${KEY_FILE}"

echo ""
echo "✅ Bootstrap complete!"
echo ""
echo "Next steps:"
echo "  export VAULT_ADDR=<your-vault-address>"
echo "  export VAULT_TOKEN=<your-vault-token>"
echo "  terraform init"
echo "  terraform plan -var-file=environments/dev/terraform.tfvars"
