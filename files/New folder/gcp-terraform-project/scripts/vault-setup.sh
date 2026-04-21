#!/usr/bin/env bash
# =============================================================================
# scripts/vault-setup.sh
#
# Sets up HashiCorp Vault policies and secret paths for this project.
# Run once against a fresh Vault instance.
#
# Requires: vault CLI, VAULT_ADDR and VAULT_TOKEN exported.
# =============================================================================
set -euo pipefail

echo "▶ Enabling KV v2 secrets engine at 'secret/'..."
vault secrets enable -path=secret kv-v2 2>/dev/null || echo "  Already enabled."

echo "▶ Writing Vault policy for Terraform runner..."
vault policy write terraform-runner - <<'EOF'
# Terraform runner can read GCP SA credentials
path "secret/data/gcp/terraform-sa" {
  capabilities = ["read"]
}
path "secret/data/gcp/terraform-sa-prod" {
  capabilities = ["read"]
}
# Allow token renewal
path "auth/token/renew-self" {
  capabilities = ["update"]
}
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
EOF

echo "▶ Writing Vault policy for developers (read-only on dev secrets)..."
vault policy write developer - <<'EOF'
path "secret/data/gcp/terraform-sa" {
  capabilities = ["read"]
}
EOF

echo "▶ Creating a periodic token for GitHub Actions..."
vault token create \
  -policy=terraform-runner \
  -period=720h \
  -display-name="github-actions-terraform" \
  -format=json | jq -r '.auth.client_token' > /tmp/github-actions-vault-token.txt

echo ""
echo "✅ Vault setup complete!"
echo ""
echo "Add the following secrets to GitHub repository settings:"
echo "  VAULT_ADDR  = ${VAULT_ADDR}"
echo "  VAULT_TOKEN = $(cat /tmp/github-actions-vault-token.txt)"
echo ""
echo "Store your GCP SA key in Vault:"
echo "  vault kv put secret/gcp/terraform-sa key=@/path/to/sa-key.json"
echo ""
rm -f /tmp/github-actions-vault-token.txt
