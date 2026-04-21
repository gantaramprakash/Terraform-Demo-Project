# environments/prod/terraform.tfvars
# ─── Production values — higher specs, tighter security ─────────────────────

project_id   = "cool-plasma-494014-t2"
region       = "asia-south1"
zone         = "asia-south1-a"
environment  = "prod"

# Network
vpc_name      = "hyderabad-vpc"
subnet_cidr   = "10.10.0.0/24"
pods_cidr     = "10.11.0.0/16"
services_cidr = "10.12.0.0/20"

# VM — standard prod instance
vm_machine_type = "e2-standard-2"
vm_image        = "debian-cloud/debian-12"

# GKE — HA regional cluster
gke_cluster_name = "hyderabad-gke"
gke_node_count   = 2
gke_machine_type = "e2-standard-4"
gke_min_nodes    = 2
gke_max_nodes    = 6

# Storage
bucket_location = "ASIA-SOUTH1"

# Pub/Sub
pubsub_topic_name = "order-events"

# Vault
vault_sa_secret_path = "secret/gcp/terraform-sa-prod"
