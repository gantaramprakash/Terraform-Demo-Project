# =============================================================================
# modules/network/main.tf
# Creates: Custom VPC, Subnet (with secondary ranges), Firewall rules,
#          Cloud Router, Cloud NAT (private egress without public IPs on VMs)
# =============================================================================

# ─── VPC ────────────────────────────────────────────────────────────────────
resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  project                 = var.project_id
  auto_create_subnetworks = false   # Always false for custom-mode VPC
  routing_mode            = "REGIONAL"

  description = "Custom VPC for ${var.environment} environment — House of Hyderabad Biryani"
}

# ─── Subnet ─────────────────────────────────────────────────────────────────
resource "google_compute_subnetwork" "primary" {
  name          = "${var.vpc_name}-subnet-${var.region}"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.subnet_cidr

  # Private Google Access lets VMs without public IPs reach Google APIs
  private_ip_google_access = true

  # Secondary ranges required for GKE VPC-native networking
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# ─── Firewall — Allow internal traffic ──────────────────────────────────────
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.vpc_name}-allow-internal"
  project = var.project_id
  network = google_compute_network.vpc.id

  description = "Allow all traffic within the VPC subnet"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [var.subnet_cidr, var.pods_cidr, var.services_cidr]
}

# ─── Firewall — Allow SSH (restricted) ──────────────────────────────────────
resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.vpc_name}-allow-ssh"
  project = var.project_id
  network = google_compute_network.vpc.id

  description = "Allow SSH only from IAP proxy range (35.235.240.0/20)"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # 35.235.240.0/20 is the Google IAP tunnel source range.
  # This means SSH is only accessible via `gcloud compute ssh --tunnel-through-iap`
  # — no direct internet exposure.
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["ssh-iap"]
}

# ─── Firewall — Allow health checks ─────────────────────────────────────────
resource "google_compute_firewall" "allow_health_checks" {
  name    = "${var.vpc_name}-allow-health-checks"
  project = var.project_id
  network = google_compute_network.vpc.id

  description = "Allow GCP load-balancer health-check probes"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["allow-health-checks"]
}

# ─── Firewall — Deny all ingress (default-deny) ──────────────────────────────
resource "google_compute_firewall" "deny_all_ingress" {
  name    = "${var.vpc_name}-deny-all-ingress"
  project = var.project_id
  network = google_compute_network.vpc.id

  description = "Default-deny all ingress; explicit allows above take precedence"
  direction   = "INGRESS"
  priority    = 65534

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}

# ─── Static IP for NAT ───────────────────────────────────────────────────────
resource "google_compute_address" "nat_ip" {
  name    = "${var.vpc_name}-nat-ip"
  project = var.project_id
  region  = var.region
}

# ─── Cloud Router ────────────────────────────────────────────────────────────
resource "google_compute_router" "router" {
  name    = "${var.vpc_name}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.vpc.id

  bgp {
    asn = 64514
  }
}

# ─── Cloud NAT ───────────────────────────────────────────────────────────────
# Allows VMs with no external IP to reach the internet (package installs, etc.)
# outbound-only — no unsolicited inbound connections.
resource "google_compute_router_nat" "nat" {
  name                               = "${var.vpc_name}-nat"
  project                            = var.project_id
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.nat_ip.self_link]
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
