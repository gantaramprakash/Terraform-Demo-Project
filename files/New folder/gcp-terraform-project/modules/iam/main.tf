# =============================================================================
# modules/iam/main.tf
# Creates least-privilege service accounts for each component.
# Rule: No human accounts in Terraform. No Editor/Owner roles anywhere.
# =============================================================================

locals {
  project = var.project_id
  env     = var.environment
}

# ─── Terraform Runner SA ─────────────────────────────────────────────────────
# Used by CI/CD (GitHub Actions) to run terraform plan/apply.
# Key JSON is stored in Vault, never in source control.
resource "google_service_account" "terraform" {
  account_id   = "sa-terraform-${local.env}"
  display_name = "Terraform Runner — ${local.env}"
  project      = local.project
  description  = "Used by GitHub Actions to run terraform plan/apply"
}

resource "google_project_iam_member" "terraform_compute_admin" {
  project = local.project
  role    = "roles/compute.admin"
  member  = "serviceAccount:${google_service_account.terraform.email}"
}

resource "google_project_iam_member" "terraform_container_admin" {
  project = local.project
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.terraform.email}"
}

resource "google_project_iam_member" "terraform_storage_admin" {
  project = local.project
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.terraform.email}"
}

resource "google_project_iam_member" "terraform_pubsub_admin" {
  project = local.project
  role    = "roles/pubsub.admin"
  member  = "serviceAccount:${google_service_account.terraform.email}"
}

resource "google_project_iam_member" "terraform_iam_admin" {
  project = local.project
  role    = "roles/iam.serviceAccountAdmin"
  member  = "serviceAccount:${google_service_account.terraform.email}"
}

resource "google_project_iam_member" "terraform_sa_token_creator" {
  project = local.project
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_service_account.terraform.email}"
}

# ─── GKE Node SA ─────────────────────────────────────────────────────────────
# Nodes run with this SA. Workload Identity adds finer-grained Pod-level access.
resource "google_service_account" "gke_node" {
  account_id   = "sa-gke-node-${local.env}"
  display_name = "GKE Node SA — ${local.env}"
  project      = local.project
  description  = "Service account for GKE node VMs (minimal scopes)"
}

# GKE nodes need to pull images from Artifact Registry
resource "google_project_iam_member" "gke_node_artifact_reader" {
  project = local.project
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

# GKE nodes write logs and metrics
resource "google_project_iam_member" "gke_node_log_writer" {
  project = local.project
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

resource "google_project_iam_member" "gke_node_metric_writer" {
  project = local.project
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

resource "google_project_iam_member" "gke_node_monitoring_viewer" {
  project = local.project
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

# Required for Workload Identity
resource "google_project_iam_member" "gke_node_workload_identity_user" {
  project = local.project
  role    = "roles/iam.workloadIdentityUser"
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

# ─── App SA (for Workload Identity) ──────────────────────────────────────────
# Kubernetes ServiceAccount "app-sa" in namespace "default" is mapped to this GCP SA.
resource "google_service_account" "app" {
  account_id   = "sa-app-${local.env}"
  display_name = "Application SA — ${local.env}"
  project      = local.project
  description  = "Used by app Pods via Workload Identity"
}

resource "google_project_iam_member" "app_pubsub_publisher" {
  project = local.project
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.app.email}"
}

resource "google_project_iam_member" "app_pubsub_subscriber" {
  project = local.project
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.app.email}"
}

resource "google_project_iam_member" "app_storage_object_user" {
  project = local.project
  role    = "roles/storage.objectUser"
  member  = "serviceAccount:${google_service_account.app.email}"
}

# Allow the Kubernetes SA to impersonate this GCP SA (Workload Identity binding)
resource "google_service_account_iam_binding" "workload_identity_binding" {
  service_account_id = google_service_account.app.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${local.project}.svc.id.goog[default/app-sa]",
  ]
}
