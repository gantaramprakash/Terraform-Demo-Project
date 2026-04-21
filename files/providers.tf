terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.0"
    }
  }

  # Remote backend — GCS bucket must be created manually before first init
  backend "gcs" {
    bucket = "cool-plasma-494014-t2-tfstate"
    prefix = "terraform/state"
  }
}

# ─── Google Provider ────────────────────────────────────────────────────────────
# Credentials come from Vault; never hardcode here.
# The GOOGLE_APPLICATION_CREDENTIALS env var is populated by the CI pipeline
# using the service-account key fetched from Vault at runtime.
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# ─── Vault Provider ─────────────────────────────────────────────────────────────
# VAULT_ADDR and VAULT_TOKEN are set as environment variables in CI/CD.
# Locally, developers run `vault login` and export VAULT_ADDR.
provider "vault" {
  # address is read from VAULT_ADDR env var
}
