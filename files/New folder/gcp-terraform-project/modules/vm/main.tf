# =============================================================================
# modules/vm/main.tf
# Creates a hardened Compute Engine instance with no public IP.
# Access is only via IAP tunnel (SSH through Google's identity proxy).
# =============================================================================

resource "google_compute_instance" "app_vm" {
  name         = "app-vm-${var.environment}"
  project      = var.project_id
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["ssh-iap", "allow-health-checks"]

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }

  boot_disk {
    initialize_params {
      image = var.image
      size  = 50   # GB
      type  = "pd-ssd"
    }
    auto_delete = true
  }

  network_interface {
    subnetwork = var.subnet_id
    # No access_config block = no ephemeral public IP.
    # Outbound traffic routes through Cloud NAT.
  }

  # Metadata startup script bootstraps the instance.
  # In prod, replace with a proper configuration management tool (Ansible/Chef).
  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io google-cloud-sdk
    systemctl enable docker
    systemctl start docker
  EOT

  service_account {
    email  = var.service_account
    # Prefer fine-grained IAM bindings over broad cloud-platform scope.
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
  }
}
