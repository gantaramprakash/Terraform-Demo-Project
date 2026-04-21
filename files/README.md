# 🏗️ GCP Infrastructure — House of Hyderabad Biryani
> **Production-ready Terraform project** for GCP — built for Infrastructure Specialist interview preparation.

---

## 📋 Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Folder Structure](#folder-structure)
4. [Components & Why Each Exists](#components--why-each-exists)
5. [Security & Secrets Flow](#security--secrets-flow)
6. [Step-by-Step Setup](#step-by-step-setup)
7. [All Commands Reference](#all-commands-reference)
8. [CI/CD Pipeline](#cicd-pipeline)
9. [Interview Talking Points](#interview-talking-points)
10. [Common Interview Questions & Answers](#common-interview-questions--answers)

---

## Project Overview

| Field        | Value                              |
|--------------|------------------------------------|
| GCP Project  | `cool-plasma-494014-t2`            |
| Region       | `asia-south1` (Mumbai)             |
| Terraform    | `>= 1.5.0`                         |
| State Backend| GCS (remote, versioned)            |
| Secrets      | HashiCorp Vault (KV v2)            |
| CI/CD        | GitHub Actions                     |
| Environments | `dev` / `prod`                     |

This project provisions a **full-stack cloud infrastructure** on GCP using modular, reusable Terraform. It follows the principle of **least privilege**, **no hardcoded credentials**, and **infrastructure-as-code best practices** throughout.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  GCP Project: cool-plasma-494014-t2                              │
│                                                                  │
│  ┌─────────────── Custom VPC (hyderabad-vpc-dev) ─────────────┐  │
│  │                                                             │  │
│  │   Subnet: 10.0.0.0/24   (asia-south1)                      │  │
│  │   Pods:   10.1.0.0/16   (GKE secondary range)              │  │
│  │   Svcs:   10.2.0.0/20   (GKE secondary range)              │  │
│  │                                                             │  │
│  │  ┌──────────────┐    ┌──────────────────────────────────┐  │  │
│  │  │  Compute VM  │    │       GKE Cluster (Regional)     │  │  │
│  │  │  (no pub IP) │    │  ┌─────────┐  ┌─────────┐        │  │  │
│  │  │  IAP SSH     │    │  │ Node 1  │  │ Node 2  │  ...   │  │  │
│  │  └──────┬───────┘    │  └─────────┘  └─────────┘        │  │  │
│  │         │            │  Workload Identity + Autoscaler   │  │  │
│  │         │            └──────────────────────────────────┘  │  │
│  │         │                          │                        │  │
│  │  ┌──────▼──────────────────────────▼──────┐                │  │
│  │  │            Cloud Router                │                │  │
│  │  │         + Cloud NAT (egress-only)       │                │  │
│  │  └────────────────────────────────────────┘                │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────┐  ┌─────────────────────────────────────────┐  │
│  │  GCS Bucket  │  │            Pub/Sub                      │  │
│  │  (versioned) │  │  Topic: order-events-dev                │  │
│  │  Lifecycle   │  │  Sub:   order-events-dev-pull-sub       │  │
│  │  policies    │  │  DLQ:   order-events-dev-dead-letter    │  │
│  └──────────────┘  └─────────────────────────────────────────┘  │
│                                                                  │
│  ┌─────────────────── IAM Service Accounts ───────────────────┐  │
│  │  sa-terraform-dev   (CI/CD runner)                         │  │
│  │  sa-gke-node-dev    (GKE nodes — minimal scopes)           │  │
│  │  sa-app-dev         (Workload Identity for pods)           │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Remote State: gs://cool-plasma-494014-t2-tfstate               │
└──────────────────────────────────────────────────────────────────┘

         ┌──────────────────────────────────┐
         │   GitHub Actions (CI/CD)         │
         │  validate → plan → apply         │
         └──────────────┬───────────────────┘
                        │ VAULT_TOKEN
                        ▼
         ┌──────────────────────────────────┐
         │   HashiCorp Vault (KV v2)        │
         │   secret/gcp/terraform-sa        │
         │     → GCP SA key JSON            │
         └──────────────────────────────────┘
```

---

## Folder Structure

```
gcp-terraform-project/
├── main.tf                        # Root module — wires all child modules
├── providers.tf                   # Google, Google-beta, Vault providers + GCS backend
├── variables.tf                   # All input variables with descriptions & validation
├── outputs.tf                     # All outputs (IPs, bucket names, cluster info)
├── .gitignore                     # Never commit *.json, *.key, *.tfstate
│
├── modules/
│   ├── network/                   # VPC, Subnet, Firewall, Router, NAT
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── vm/                        # Compute Engine (Shielded VM, no public IP)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── gke/                       # GKE regional cluster + node pool
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── storage/                   # GCS bucket (versioned, lifecycle policies)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── pubsub/                    # Topic + Pull sub + Dead-letter topic
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── iam/                       # Service accounts + least-privilege bindings
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
├── environments/
│   ├── dev/
│   │   └── terraform.tfvars       # Dev-specific variable overrides
│   └── prod/
│       └── terraform.tfvars       # Prod-specific variable overrides
│
├── scripts/
│   ├── bootstrap.sh               # One-time GCS bucket + SA creation
│   ├── vault-setup.sh             # Vault policy + secrets setup
│   └── destroy.sh                 # Safe destroy with prod confirmation gate
│
└── .github/
    └── workflows/
        └── terraform.yml          # GitHub Actions: validate → plan → apply
```

---

## Components & Why Each Exists

### 🌐 Custom VPC (`modules/network`)
**Why:** GCP's default VPC is auto-mode and insecure for production — subnets in every region, open firewall rules. A custom VPC gives you full control over IP ranges, routing, and firewall posture.

**Key decisions:**
- `auto_create_subnetworks = false` — custom mode VPC, you control every subnet
- `private_ip_google_access = true` — VMs without public IPs can reach Google APIs (Cloud Storage, Pub/Sub)
- Secondary IP ranges (`pods`, `services`) — required for GKE VPC-native networking (alias IPs)
- Subnet flow logs — audit trail for compliance

### 🔥 Firewall Rules
**Why:** Defence-in-depth. Default-deny with explicit allows.

| Rule | Source | Purpose |
|------|--------|---------|
| `allow-internal` | VPC CIDR + pod/svc ranges | East-west traffic between services |
| `allow-ssh` | `35.235.240.0/20` (IAP) | SSH only via Identity-Aware Proxy — no internet exposure |
| `allow-health-checks` | GCP LB ranges | Load balancer probes |
| `deny-all-ingress` | `0.0.0.0/0` | Catch-all default deny |

### 🔄 Cloud NAT (`modules/network`)
**Why:** VMs and GKE nodes have no public IPs (security requirement), but still need outbound internet access to pull packages, container images, etc. Cloud NAT provides outbound-only NAT — no unsolicited inbound connections possible.

Real-world pattern: All workloads stay private. Only the load balancer has a public IP.

### 💻 Compute Engine VM (`modules/vm`)
**Why:** Represents a bastion / utility VM or a single-instance app. Demonstrates:
- Shielded VM config (Secure Boot, vTPM, Integrity Monitoring)
- IAP-only SSH access (no public IP required)
- Service account attachment (not personal credentials)

### ☸️ GKE Cluster (`modules/gke`)
**Why:** Container orchestration at scale. This setup uses a **regional cluster** (HA across zones) with:
- `remove_default_node_pool = true` + separate `google_container_node_pool` — gives independent lifecycle control
- **Workload Identity** — maps Kubernetes ServiceAccounts to GCP SAs; no key files on nodes
- **VPC-native networking** — pods get real VPC IPs (not double-NAT), enabling direct service routing
- **Network Policy (Calico)** — pod-level firewall rules
- **Release channel `REGULAR`** — GKE manages patch/minor upgrades automatically

### 🪣 Cloud Storage (`modules/storage`)
**Why:** Object store for app assets, backups, data pipeline outputs.

Key production settings:
- `uniform_bucket_level_access = true` — disables legacy ACLs; all access via IAM only
- Versioning — protects against accidental deletes
- Lifecycle rules — auto-transition old versions to Nearline (cheaper), then delete after 1 year
- `force_destroy = false` in prod — prevents accidental `terraform destroy` data loss

### 📨 Pub/Sub (`modules/pubsub`)
**Why:** Asynchronous event streaming between microservices. Real-world use: order placed → publish to `order-events` topic → inventory, notification, and analytics services subscribe independently.

Includes:
- **Dead-letter topic** — messages that fail after 5 attempts land here for debugging
- **Retry policy** — exponential backoff (10s to 600s) before dead-lettering
- Pull subscription — consumer controls the read rate

### 🔐 IAM (`modules/iam`)
**Why:** Least-privilege service accounts per component. No human accounts, no `roles/Editor`.

| Service Account | Role(s) | Used By |
|-----------------|---------|---------|
| `sa-terraform-dev` | compute.admin, container.admin, storage.admin, pubsub.admin | GitHub Actions |
| `sa-gke-node-dev` | artifactregistry.reader, logging.logWriter, monitoring.metricWriter | GKE node VMs |
| `sa-app-dev` | pubsub.publisher, pubsub.subscriber, storage.objectUser | App pods (via Workload Identity) |

---

## Security & Secrets Flow

### How Vault integrates with Terraform

```
┌─────────────────────────────────────────────────────────────────┐
│                    Secrets Flow                                  │
│                                                                  │
│  1. Bootstrap (one-time, by human):                             │
│     gcloud iam service-accounts keys create sa-key.json        │
│     vault kv put secret/gcp/terraform-sa key=@sa-key.json      │
│     rm sa-key.json  ← key never persists locally               │
│                                                                  │
│  2. GitHub Actions runtime:                                     │
│     vault-action reads VAULT_TOKEN from GitHub Secret           │
│     → fetches secret/gcp/terraform-sa                          │
│     → writes JSON to /tmp/sa-key.json in runner                │
│     → sets GOOGLE_APPLICATION_CREDENTIALS env var              │
│     → terraform init/plan/apply uses the credential            │
│     → runner exits, /tmp/sa-key.json is destroyed              │
│                                                                  │
│  3. Terraform Vault provider (runtime):                         │
│     data "vault_generic_secret" "gcp_sa" {                      │
│       path = "secret/gcp/terraform-sa"                          │
│     }                                                            │
│     Reads sensitive values into Terraform state (encrypted)     │
│                                                                  │
│  ✅ SA key JSON never exists in:                                │
│     • Source code                                               │
│     • Git history                                               │
│     • Terraform .tfvars files                                   │
│     • GitHub Actions logs (masked by vault-action)             │
└─────────────────────────────────────────────────────────────────┘
```

### Security hardening checklist
- [x] No public IPs on VMs or GKE nodes
- [x] SSH only via IAP (no port 22 to internet)
- [x] Shielded VMs (Secure Boot + vTPM)
- [x] Workload Identity (no SA key files on nodes)
- [x] Uniform bucket-level access (no legacy ACLs)
- [x] Network Policy on GKE (pod-level firewall)
- [x] Default-deny ingress firewall
- [x] Remote state in GCS with versioning
- [x] `sensitive = true` on secret outputs
- [x] `.gitignore` blocks *.json, *.key, *.tfstate

---

## Step-by-Step Setup

### Prerequisites

```bash
# Install required tools
brew install terraform google-cloud-sdk vault jq   # macOS
# or
apt-get install terraform google-cloud-sdk vault jq  # Ubuntu

# Verify versions
terraform version    # >= 1.5.0
gcloud version
vault version
```

### Step 1 — Authenticate gcloud

```bash
gcloud auth login
gcloud config set project cool-plasma-494014-t2
gcloud auth application-default login
```

### Step 2 — Clone and enter the project

```bash
git clone https://github.com/<your-username>/gcp-terraform-project.git
cd gcp-terraform-project
git init   # if starting fresh
```

### Step 3 — Bootstrap (one-time only)

This creates the GCS state bucket, the Terraform SA, and uploads the key to Vault.

```bash
# Set Vault connection details
export VAULT_ADDR="http://127.0.0.1:8200"   # Replace with your Vault address
export VAULT_TOKEN="<your-root-or-admin-token>"

# Run bootstrap
chmod +x scripts/bootstrap.sh
./scripts/bootstrap.sh
```

### Step 4 — Configure Vault policies

```bash
chmod +x scripts/vault-setup.sh
./scripts/vault-setup.sh
# Follow the output instructions to add secrets to GitHub
```

### Step 5 — Terraform Init

```bash
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="<your-token>"

terraform init
# Expected output:
# Initializing the backend...
# Successfully configured the backend "gcs"!
# Terraform has been successfully initialized!
```

### Step 6 — Plan

```bash
# Dev environment
terraform plan -var-file=environments/dev/terraform.tfvars

# Prod environment
terraform plan -var-file=environments/prod/terraform.tfvars
```

### Step 7 — Apply

```bash
# Dev
terraform apply -var-file=environments/dev/terraform.tfvars

# Prod (requires explicit approval)
terraform apply -var-file=environments/prod/terraform.tfvars
```

### Step 8 — Access GKE

```bash
gcloud container clusters get-credentials hyderabad-gke-dev \
  --region asia-south1 \
  --project cool-plasma-494014-t2

kubectl get nodes
kubectl get pods --all-namespaces
```

### Step 9 — SSH into VM via IAP

```bash
gcloud compute ssh app-vm-dev \
  --tunnel-through-iap \
  --zone asia-south1-a \
  --project cool-plasma-494014-t2
```

---

## All Commands Reference

```bash
# ─── Terraform lifecycle ────────────────────────────────────────────────────
terraform init                                              # Initialize providers + backend
terraform validate                                          # Syntax + schema check
terraform fmt -recursive                                    # Auto-format all .tf files
terraform plan  -var-file=environments/dev/terraform.tfvars    # Preview changes
terraform apply -var-file=environments/dev/terraform.tfvars    # Apply changes
terraform apply -var-file=environments/dev/terraform.tfvars -auto-approve  # No prompt
terraform destroy -var-file=environments/dev/terraform.tfvars  # Tear down (use destroy.sh)

# ─── Targeted operations ────────────────────────────────────────────────────
terraform plan -target=module.network                       # Plan only network module
terraform apply -target=module.gke                          # Apply only GKE module
terraform state list                                        # List all managed resources
terraform state show module.vm.google_compute_instance.app_vm  # Inspect resource state

# ─── Import existing resource ───────────────────────────────────────────────
terraform import module.storage.google_storage_bucket.app \
  cool-plasma-494014-t2-app-dev

# ─── Taint / Replace ────────────────────────────────────────────────────────
terraform apply -replace=module.vm.google_compute_instance.app_vm

# ─── Output values ──────────────────────────────────────────────────────────
terraform output                                            # All outputs
terraform output gke_kubeconfig_command                    # Single output
terraform output -json                                      # JSON format

# ─── GKE ────────────────────────────────────────────────────────────────────
gcloud container clusters get-credentials hyderabad-gke-dev \
  --region asia-south1 --project cool-plasma-494014-t2
kubectl get nodes -o wide
kubectl top nodes

# ─── Pub/Sub testing ────────────────────────────────────────────────────────
gcloud pubsub topics publish order-events-dev \
  --message='{"order_id":"123","status":"placed"}'
gcloud pubsub subscriptions pull order-events-dev-pull-sub --auto-ack

# ─── GCS ────────────────────────────────────────────────────────────────────
gsutil ls gs://cool-plasma-494014-t2-app-dev
gsutil cp localfile.txt gs://cool-plasma-494014-t2-app-dev/

# ─── Vault ──────────────────────────────────────────────────────────────────
vault kv put secret/gcp/terraform-sa key=@sa-key.json
vault kv get secret/gcp/terraform-sa
vault token lookup

# ─── Destroy ────────────────────────────────────────────────────────────────
./scripts/destroy.sh dev          # Dev destroy (no confirmation needed)
./scripts/destroy.sh prod         # Prod destroy (requires typing 'destroy-prod')
```

---

## CI/CD Pipeline

```
PR opened
    │
    ▼
┌─────────────┐     ┌──────────────┐     ┌──────────────────────┐
│  validate   │────▶│   security   │────▶│   plan               │
│             │     │  (tfsec)     │     │  Posts diff to PR    │
│ fmt + init  │     │              │     │  Saves tfplan        │
│ + validate  │     │              │     │  artifact            │
└─────────────┘     └──────────────┘     └──────────┬───────────┘
                                                     │
                                              PR merged to main
                                                     │
                                                     ▼
                                         ┌─────────────────────┐
                                         │  apply              │
                                         │  (manual approval   │
                                         │   gate on prod)     │
                                         │  Downloads tfplan   │
                                         │  terraform apply    │
                                         └─────────────────────┘
```

**GitHub Secrets required:**

| Secret | Description |
|--------|-------------|
| `VAULT_ADDR` | URL of your Vault server |
| `VAULT_TOKEN` | Vault token with `terraform-runner` policy |

**GitHub Environments to create:**
- `dev` — auto-approve deploys
- `prod` — add required reviewer(s) for manual approval gate

---

## Interview Talking Points

### 1. Why modules over monolithic Terraform?
> Modules enforce the **single-responsibility principle** — each module owns one domain (network, compute, GKE). This means: independent `terraform apply -target`, isolated state for blast radius control, reuse across environments/projects, and testability with tools like Terratest.

### 2. Why remote state in GCS?
> Local state breaks team workflows — concurrent applies cause state corruption. GCS backend gives you **state locking via Cloud Spanner** (built into the GCS backend), versioning for rollback, and encryption at rest. The state bucket is bootstrapped manually to avoid the chicken-and-egg problem.

### 3. Why Cloud NAT instead of public IPs?
> Public IPs on every VM are an attack surface. Cloud NAT lets private instances reach the internet for outbound traffic (package installs, image pulls) while being completely unreachable from the internet inbound. Combined with IAP for SSH, zero resources need a public IP.

### 4. Why Workload Identity over SA key files?
> SA key files are long-lived credentials that can leak via code, logs, or storage. Workload Identity federates Kubernetes ServiceAccounts with GCP IAM at the API level — no JSON key files exist. Access is automatically rotated via short-lived tokens issued by the GKE metadata server.

### 5. Why a regional GKE cluster?
> Zonal clusters have a single-point-of-failure on the control plane. A regional cluster replicates the control plane across 3 zones. Node pools span all zones by default. For prod, this means no downtime during GCP zonal maintenance windows.

### 6. How do you handle secrets rotation?
> SA keys stored in Vault can be rotated by: (1) generating a new key, (2) `vault kv put` to update the secret, (3) CI re-reads on next pipeline run. The old key can be revoked in IAM. Workload Identity tokens rotate automatically every hour — no manual rotation needed for pod credentials.

### 7. What is the blast radius of this setup?
> Each component is isolated in its own module with its own service account. If a storage bucket is misconfigured, it cannot affect the GKE cluster's IAM. Module-level `depends_on` controls creation order. Targeted destroys (`-target`) let you tear down one component without touching others.

---

## Common Interview Questions & Answers

**Q: What happens if two engineers run `terraform apply` simultaneously?**
> The GCS backend uses **state locking**. The second apply will fail with a lock error and show the lock ID + the identity that holds it. You can force-unlock with `terraform force-unlock <lock-id>` if the holder crashed — but always verify the other apply completed first.

**Q: How do you manage Terraform across multiple environments without code duplication?**
> Environment-specific `terraform.tfvars` files override root variable defaults. The modules are environment-agnostic; they accept `var.environment` and use it in naming/labels. For larger orgs, Terragrunt adds DRY wrappers and remote state config per environment.

**Q: What is VPC-native GKE and why does it matter?**
> VPC-native (alias IP) clusters assign pod IPs from a subnet secondary range. This means pods are first-class VPC citizens — you can create firewall rules targeting pod IP ranges directly, route traffic to pods from on-prem via VPN/Interconnect, and avoid double-NAT. The alternative (routes-based) clusters have a limit of 1000 routes per VPC and can't use Network Policy.

**Q: How would you debug a GKE pod that can't reach Cloud Storage?**
> Checklist: (1) Is `private_ip_google_access = true` on the subnet? (2) Does the pod's GCP SA (`sa-app-dev`) have `roles/storage.objectUser`? (3) Is the Workload Identity annotation on the Kubernetes SA correct? (4) `kubectl exec` into the pod and test `gcloud storage ls` with the workload identity credential.

**Q: What's the difference between `terraform taint` and `terraform apply -replace`?**
> `taint` was deprecated in Terraform 0.15.2. The modern equivalent is `terraform apply -replace=<resource>`. Both mark a resource for destruction and recreation in the next apply. Use case: force-recreate a VM after a startup script change that doesn't trigger a diff in Terraform.

**Q: How does Pub/Sub guarantee delivery?**
> Pub/Sub is an at-least-once delivery system. Messages are persisted until acknowledged. The subscription's `ack_deadline_seconds` (60s here) gives consumers time to process before re-delivery. The dead-letter policy catches messages that fail 5 times, preventing poison-pill messages from blocking the subscription.

**Q: How would you add a new environment (e.g., staging)?**
> 1. Create `environments/staging/terraform.tfvars` with staging-specific values.
> 2. Update the GCS backend `prefix` to `terraform/staging` (or use a workspace).
> 3. Run `terraform init` with the new backend config.
> 4. `terraform apply -var-file=environments/staging/terraform.tfvars`.
> No module changes needed — the modules are environment-agnostic.

**Q: What would you add to make this truly production-grade?**
> - **Cloud Armor** WAF in front of the GKE ingress
> - **Binary Authorization** to enforce only signed container images
> - **VPC Service Controls** to prevent data exfiltration from GCS/BigQuery
> - **Cloud Interconnect or HA VPN** for on-prem connectivity
> - **Artifact Registry** for private container images
> - **Cloud Monitoring alerts** with PagerDuty/OpsGenie integration
> - **Terraform Cloud/Spacelift** for enterprise-grade state management and policy enforcement (Sentinel/OPA)
> - **Customer-Managed Encryption Keys (CMEK)** for GCS, GKE, and Pub/Sub

---

*Built with ❤️ for interview preparation — House of Hyderabad Biryani Infrastructure*
#   T e r r a f o r m - D e m o - P r o j e c t  
 