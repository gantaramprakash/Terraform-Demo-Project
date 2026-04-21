# =============================================================================
# modules/pubsub/main.tf
# Creates a Pub/Sub topic + pull subscription for async event streaming.
# Pattern: Cloud Run / GKE services publish order events; consumers pull.
# =============================================================================

resource "google_pubsub_topic" "main" {
  name    = var.topic_name
  project = var.project_id

  # Retain undelivered messages for 7 days
  message_retention_duration = "604800s"

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# Dead-letter topic — catches messages that fail after max_delivery_attempts
resource "google_pubsub_topic" "dead_letter" {
  name    = "${var.topic_name}-dead-letter"
  project = var.project_id

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# ─── Pull Subscription ───────────────────────────────────────────────────────
resource "google_pubsub_subscription" "pull" {
  name    = "${var.topic_name}-pull-sub"
  project = var.project_id
  topic   = google_pubsub_topic.main.id

  ack_deadline_seconds = 60

  # Keep unacknowledged messages for 7 days
  message_retention_duration = "604800s"
  retain_acked_messages      = false

  expiration_policy {
    ttl = ""   # Never expire the subscription
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = 5
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# ─── Push Subscription (optional — uncomment when Cloud Run endpoint exists) ─
# resource "google_pubsub_subscription" "push" {
#   name  = "${var.topic_name}-push-sub"
#   topic = google_pubsub_topic.main.id
#   push_config {
#     push_endpoint = var.push_endpoint
#     oidc_token {
#       service_account_email = var.push_sa_email
#     }
#   }
# }
