# =============================================================================
# modules/storage/main.tf
# Creates a production-hardened GCS bucket:
#   - Versioning enabled
#   - Uniform bucket-level access (no legacy ACLs)
#   - Lifecycle policy to transition old versions to Nearline
#   - CMEK-ready (uses Google-managed key by default; swap for CMEK in prod)
# =============================================================================

resource "google_storage_bucket" "app" {
  name          = var.bucket_name
  project       = var.project_id
  location      = var.bucket_location
  storage_class = "STANDARD"

  # Prevent accidental deletion of the bucket
  force_destroy = var.environment == "dev" ? true : false

  uniform_bucket_level_access = true   # Disables legacy object-level ACLs

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age                   = 30
      num_newer_versions    = 3
      with_state            = "ARCHIVED"
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age            = 365
      with_state     = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD"]
    response_header = ["Content-Type"]
    max_age_seconds = 3600
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# ─── State bucket (created once, manually or via bootstrap script) ───────────
# The tfstate bucket is NOT managed in this module to avoid chicken-and-egg.
# See scripts/bootstrap.sh for the one-time setup command.
