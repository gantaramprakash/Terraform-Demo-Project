# environments/dev/terraform.tfvars
# ─── All values here override root variable defaults for DEV ─────────────────

project_id   = "cool-plasma-494014-t2"
region       = "asia-south1"
zone         = "asia-south1-a"
environment  = "dev"

# Network
vpc_name      = "hyderabad-vpc"
subnet_cidr   = "10.0.0.0/24"
pods_cidr     = "10.1.0.0/16"
services_cidr = "10.2.0.0/20"

# VM — smaller instance for dev
vm_machine_type = "e2-micro"
vm_image        = "debian-cloud/debian-12"

# GKE — single-node to save cost in dev
gke_cluster_name = "hyderabad-gke"
gke_node_count   = 1
gke_machine_type = "e2-standard-2"
gke_min_nodes    = 1
gke_max_nodes    = 2

# Storage
bucket_location = "ASIA-SOUTH1"

# Pub/Sub
pubsub_topic_name = "order-events"

# Vault
vault_sa_secret_path = "secret/gcp/terraform-sa"
