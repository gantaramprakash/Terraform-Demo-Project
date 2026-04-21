#!/usr/bin/env bash
# =============================================================================
# scripts/destroy.sh
# Safely destroys infrastructure for a given environment.
# Usage: ./scripts/destroy.sh dev
# =============================================================================
set -euo pipefail

ENV="${1:-dev}"

if [[ "${ENV}" == "prod" ]]; then
  echo "⚠️  You are about to DESTROY PRODUCTION infrastructure!"
  read -r -p "Type 'destroy-prod' to confirm: " CONFIRM
  if [[ "${CONFIRM}" != "destroy-prod" ]]; then
    echo "Aborted."
    exit 1
  fi
fi

echo "▶ Destroying ${ENV} environment..."
terraform destroy \
  -var-file="environments/${ENV}/terraform.tfvars" \
  -auto-approve

echo "✅ Destroy complete for ${ENV}."
