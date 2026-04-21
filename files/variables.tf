# ─── Project ────────────────────────────────────────────────────────────────────
variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "cool-plasma-494014-t2"
}

variable "region" {
  description = "Default GCP region"
  type        = string
  default     = "asia-south1"
}

variable "zone" {
  description = "Default GCP zone"
  type        = string
  default     = "asia-south1-a"
}

variable "environment" {
  description = "Deployment environment (dev | prod)"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be 'dev' or 'prod'."
  }
}

# ─── Network ────────────────────────────────────────────────────────────────────
variable "vpc_name" {
  description = "Name of the custom VPC"
  type        = string
  default     = "hyderabad-vpc"
}

variable "subnet_cidr" {
  description = "CIDR block for the primary subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "pods_cidr" {
  description = "Secondary CIDR range for GKE pods"
  type        = string
  default     = "10.1.0.0/16"
}

variable "services_cidr" {
  description = "Secondary CIDR range for GKE services"
  type        = string
  default     = "10.2.0.0/20"
}

# ─── VM ─────────────────────────────────────────────────────────────────────────
variable "vm_machine_type" {
  description = "Machine type for the Compute Engine instance"
  type        = string
  default     = "e2-medium"
}

variable "vm_image" {
  description = "Boot disk image for the VM"
  type        = string
  default     = "debian-cloud/debian-12"
}

# ─── GKE ────────────────────────────────────────────────────────────────────────
variable "gke_cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "hyderabad-gke"
}

variable "gke_node_count" {
  description = "Initial number of nodes per zone"
  type        = number
  default     = 1
}

variable "gke_machine_type" {
  description = "Machine type for GKE node pool"
  type        = string
  default     = "e2-standard-2"
}

variable "gke_min_nodes" {
  description = "Minimum nodes for autoscaling"
  type        = number
  default     = 1
}

variable "gke_max_nodes" {
  description = "Maximum nodes for autoscaling"
  type        = number
  default     = 3
}

# ─── Storage ────────────────────────────────────────────────────────────────────
variable "bucket_location" {
  description = "GCS bucket location"
  type        = string
  default     = "ASIA-SOUTH1"
}

# ─── Pub/Sub ────────────────────────────────────────────────────────────────────
variable "pubsub_topic_name" {
  description = "Name of the Pub/Sub topic"
  type        = string
  default     = "order-events"
}

# ─── Vault ──────────────────────────────────────────────────────────────────────
variable "vault_sa_secret_path" {
  description = "Vault KV path where the GCP service account key JSON is stored"
  type        = string
  default     = "secret/gcp/terraform-sa"
}
