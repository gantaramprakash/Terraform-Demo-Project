# =============================================================================
# modules/gke/main.tf
# Creates a private, VPC-native GKE cluster with:
#   - Workload Identity (avoids node-level service account key files)
#   - Shielded nodes
#   - Horizontal Pod Autoscaler + Cluster Autoscaler
#   - Binary Authorization ready
# =============================================================================

resource "google_container_cluster" "primary" {
  provider = google-beta

  name     = var.cluster_name
  project  = var.project_id
  location = var.region   # regional cluster = HA across zones

  # VPC-native networking (alias IPs)
  networking_mode = "VPC_NATIVE"
  network         = "projects/${var.project_id}/global/networks/${split("/", var.subnet_id)[length(split("/", var.subnet_id)) - 3]}"
  subnetwork      = var.subnet_id

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_cidr_name
    services_secondary_range_name = var.services_cidr_name
  }

  # Private cluster — nodes have no public IPs
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false   # Keep master endpoint reachable for CI
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Remove the default node pool; we manage node pools separately
  remove_default_node_pool = true
  initial_node_count       = 1

  # Workload Identity — recommended way to access GCP APIs from Pods
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
  }

  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  release_channel {
    channel = "REGULAR"   # Managed patch/minor upgrades
  }

  maintenance_policy {
    recurring_window {
      start_time = "2024-01-01T02:00:00Z"
      end_time   = "2024-01-01T06:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SA,SU"
    }
  }

  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }

  lifecycle {
    ignore_changes = [
      # Prevent drift from minor version auto-upgrades
      node_version,
      master_version,
    ]
  }
}

# ─── Node Pool ───────────────────────────────────────────────────────────────
resource "google_container_node_pool" "primary_nodes" {
  name     = "${var.cluster_name}-node-pool"
  project  = var.project_id
  location = var.region
  cluster  = google_container_cluster.primary.name

  initial_node_count = var.node_count

  autoscaling {
    min_node_count = var.min_nodes
    max_node_count = var.max_nodes
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.machine_type
    disk_type       = "pd-ssd"
    disk_size_gb    = 100
    image_type      = "COS_CONTAINERD"   # Container-Optimized OS
    service_account = var.gke_sa_email

    # Minimal scopes — actual permissions come from Workload Identity IAM bindings
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"   # Enables Workload Identity on nodes
    }

    labels = {
      environment = var.environment
      node_pool   = "primary"
    }

    tags = ["gke-node", var.cluster_name]
  }
}
