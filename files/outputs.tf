# ─── Network ────────────────────────────────────────────────────────────────────
output "vpc_id" {
  description = "Self-link of the custom VPC"
  value       = module.network.vpc_id
}

output "subnet_id" {
  description = "Self-link of the primary subnet"
  value       = module.network.subnet_id
}

output "nat_ip" {
  description = "Static external IP allocated to the Cloud NAT gateway"
  value       = module.network.nat_ip
}

# ─── VM ─────────────────────────────────────────────────────────────────────────
output "vm_internal_ip" {
  description = "Internal IP of the Compute Engine instance"
  value       = module.vm.internal_ip
}

output "vm_name" {
  description = "Name of the Compute Engine instance"
  value       = module.vm.instance_name
}

# ─── GKE ────────────────────────────────────────────────────────────────────────
output "gke_cluster_name" {
  description = "GKE cluster name"
  value       = module.gke.cluster_name
}

output "gke_endpoint" {
  description = "GKE cluster API endpoint"
  value       = module.gke.endpoint
  sensitive   = true
}

output "gke_kubeconfig_command" {
  description = "Command to fetch kubeconfig for this cluster"
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --region ${var.region} --project ${var.project_id}"
}

# ─── Storage ────────────────────────────────────────────────────────────────────
output "gcs_bucket_name" {
  description = "Name of the application GCS bucket"
  value       = module.storage.bucket_name
}

output "gcs_bucket_url" {
  description = "gs:// URL of the GCS bucket"
  value       = module.storage.bucket_url
}

# ─── Pub/Sub ────────────────────────────────────────────────────────────────────
output "pubsub_topic_id" {
  description = "Pub/Sub topic resource ID"
  value       = module.pubsub.topic_id
}

output "pubsub_subscription_id" {
  description = "Pub/Sub pull subscription resource ID"
  value       = module.pubsub.subscription_id
}

# ─── IAM ────────────────────────────────────────────────────────────────────────
output "terraform_sa_email" {
  description = "Email of the Terraform service account"
  value       = module.iam.terraform_sa_email
}

output "gke_sa_email" {
  description = "Email of the GKE node service account"
  value       = module.iam.gke_sa_email
}
