# =============================================================================
# main.tf — Root Module
# Wires together all child modules. Values are driven by environment-specific
# tfvars (environments/dev/terraform.tfvars or environments/prod/terraform.tfvars).
# =============================================================================

# ─── Pull GCP SA key from Vault ─────────────────────────────────────────────
# The vault_generic_secret data source reads the service-account JSON
# stored at var.vault_sa_secret_path so it NEVER touches source control.
data "vault_generic_secret" "gcp_sa" {
  path = var.vault_sa_secret_path
}

# ─── IAM / Service Accounts ─────────────────────────────────────────────────
module "iam" {
  source     = "./modules/iam"
  project_id = var.project_id
  environment = var.environment
}

# ─── Network ────────────────────────────────────────────────────────────────
module "network" {
  source        = "./modules/network"
  project_id    = var.project_id
  region        = var.region
  environment   = var.environment
  vpc_name      = "${var.vpc_name}-${var.environment}"
  subnet_cidr   = var.subnet_cidr
  pods_cidr     = var.pods_cidr
  services_cidr = var.services_cidr
}

# ─── Compute Engine VM ──────────────────────────────────────────────────────
module "vm" {
  source          = "./modules/vm"
  project_id      = var.project_id
  zone            = var.zone
  environment     = var.environment
  subnet_id       = module.network.subnet_id
  machine_type    = var.vm_machine_type
  image           = var.vm_image
  service_account = module.iam.terraform_sa_email

  depends_on = [module.network, module.iam]
}

# ─── GKE Cluster ────────────────────────────────────────────────────────────
module "gke" {
  source           = "./modules/gke"
  project_id       = var.project_id
  region           = var.region
  environment      = var.environment
  cluster_name     = "${var.gke_cluster_name}-${var.environment}"
  subnet_id        = module.network.subnet_id
  pods_cidr_name   = module.network.pods_cidr_name
  services_cidr_name = module.network.services_cidr_name
  node_count       = var.gke_node_count
  machine_type     = var.gke_machine_type
  min_nodes        = var.gke_min_nodes
  max_nodes        = var.gke_max_nodes
  gke_sa_email     = module.iam.gke_sa_email

  depends_on = [module.network, module.iam]
}

# ─── Cloud Storage ──────────────────────────────────────────────────────────
module "storage" {
  source          = "./modules/storage"
  project_id      = var.project_id
  environment     = var.environment
  bucket_location = var.bucket_location
  # Bucket name must be globally unique; prefix with project ID
  bucket_name     = "${var.project_id}-app-${var.environment}"

  depends_on = [module.iam]
}

# ─── Pub/Sub ────────────────────────────────────────────────────────────────
module "pubsub" {
  source           = "./modules/pubsub"
  project_id       = var.project_id
  environment      = var.environment
  topic_name       = "${var.pubsub_topic_name}-${var.environment}"

  depends_on = [module.iam]
}
