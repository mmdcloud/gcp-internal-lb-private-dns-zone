# GCP Producer/Consumer VPC Peering Platform

[![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Google Cloud](https://img.shields.io/badge/GoogleCloud-%234285F4.svg?style=for-the-badge&logo=google-cloud&logoColor=white)](https://cloud.google.com/)

Terraform configuration that provisions a two-VPC ("producer" and "consumer")
network topology on Google Cloud, peered together, with a NAT-enabled
producer network hosting an autoscaled, load-balanced NGINX service and a
standalone consumer VM for connectivity validation. A private DNS zone
resolves the load balancer's IP inside the peered networks.

> **Status:** This README was generated from the root Terraform module
> (`main.tf`). It documents inferred variables and outputs based on resource
> references; reconcile the **Inputs** and **Outputs** tables below against
> your actual `variables.tf` / `outputs.tf` before treating this as
> authoritative.

---

## Table of Contents

- [Architecture](#architecture)
- [What Gets Deployed](#what-gets-deployed)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Inputs](#inputs)
- [Outputs](#outputs)
- [Usage](#usage)
- [Security Considerations](#security-considerations)
- [Cost Considerations](#cost-considerations)
- [Known Limitations / TODOs](#known-limitations--todos)
- [Cleanup](#cleanup)

---

## Architecture

```
                         Internet
                            │
                  ┌─────────▼──────────┐
                  │  Global HTTP(S) LB  │  (Cloud Armor + HTTP→HTTPS redirect)
                  └─────────┬──────────┘
                            │
                 ┌──────────▼───────────┐
                 │   producer-vpc        │  10.1.0.0/24  (producer_region)
                 │  ┌─────────────────┐  │
                 │  │  MIG (1-5)      │  │  e2-medium, private IP only
                 │  │  producer-instance-template │
                 │  └────────┬────────┘  │
                 │           │ egress    │
                 │   ┌───────▼────────┐  │
                 │   │ Cloud Router +  │  │
                 │   │ Cloud NAT       │  │
                 │   └────────────────┘  │
                 └──────────┬────────────┘
                             │ VPC Peering (bidirectional)
                 ┌───────────▼───────────┐
                 │   consumer-vpc         │  10.2.0.0/24  (consumer_region)
                 │  ┌──────────────────┐  │
                 │  │ consumer-instance │  │  e2-micro, private IP only
                 │  └──────────────────┘  │
                 └────────────────────────┘

           Private DNS zone (attached to var.vpc_network_self_links)
           A record → Load Balancer IP
```

## What Gets Deployed

| Component | Resource(s) | Notes |
|---|---|---|
| **Networking** | `module.producer_vpc`, `module.consumer_vpc` | Custom-mode VPCs, `REGIONAL` routing, one subnet each (`10.1.0.0/24`, `10.2.0.0/24`), default routes not auto-deleted |
| **Firewalls** | Per-VPC allow rules for TCP 80, 443, 22 | Source range `0.0.0.0/0`, scoped by target tag (`producer-instance` / `consumer-instance`) |
| **NAT / Egress** | `google_compute_router.router`, `google_compute_router_nat.router_nat` | Producer VPC only; `AUTO_ONLY` IP allocation, NATs all subnets/ranges, error-only logging |
| **VPC Peering** | `google_compute_network_peering.producer_to_consumer_peering` / `consumer_to_producer_peering` | Bidirectional; custom routes are imported but not exported on either side |
| **Compute (producer)** | `module.instance_template`, `module.mig` | Ubuntu minimal image, `e2-medium`, 50 GB `pd-balanced` disk, no public IP, dedicated service account (`logging.logWriter`, `monitoring.metricWriter`); MIG autoscales 1–5 instances behind an HTTP health check on `/` |
| **Load Balancer** | `module.lb` | Global HTTP(S) LB fronting the MIG, Cloud Armor enabled, HTTP→HTTPS redirect enabled, custom domain via `var.domain` |
| **DNS** | `google_dns_managed_zone.private_zone`, `google_dns_record_set.record` | Private zone visible to networks in `var.vpc_network_self_links`; A record resolves to the LB IP |
| **Compute (consumer)** | `module.consumer_instance` | Single `e2-micro` VM, no external IP, NGINX installed via startup script, used to validate cross-VPC/peering connectivity |

Each producer/consumer instance bootstraps NGINX via a startup script and
serves a simple "Hello World" page identifying the hostname.

## Repository Structure

```
.
├── main.tf                     # Root module (this file)
├── variables.tf                # Input variable declarations (not shown)
├── outputs.tf                  # Output declarations (not shown)
├── modules/
│   ├── vpc/                    # VPC + subnet(s) + firewall rules
│   ├── instance-template/      # Compute instance template + service account
│   ├── mig/                    # Managed instance group + autoscaler + health check
│   ├── load-balancer/          # Global HTTP(S) LB + Cloud Armor + redirect
│   └── compute/                # Standalone compute instance
```

## Prerequisites

- **Terraform** >= 1.5 (recommended; pin via `required_version` in a
  `versions.tf` if not already present)
- **Google Cloud provider** (`hashicorp/google`), version pinned in
  `versions.tf`
- A GCP project with billing enabled and the following APIs enabled:
  - `compute.googleapis.com`
  - `dns.googleapis.com`
  - `iam.googleapis.com`
  - `servicenetworking.googleapis.com` (if peering is extended to managed services)
- Credentials with sufficient IAM permissions to create VPCs, firewall rules,
  Cloud Router/NAT, compute instances/MIGs, load balancers, Cloud Armor
  policies, service accounts, and Cloud DNS zones/records
  (e.g., `roles/compute.networkAdmin`, `roles/compute.instanceAdmin.v1`,
  `roles/iam.serviceAccountAdmin`, `roles/dns.admin`)
- A registered domain (or delegated DNS zone) if you intend to serve
  production traffic over `var.domain` with a managed SSL certificate

## Inputs

> Inferred from resource references in `main.tf`. Confirm types, defaults,
> and validation rules against `variables.tf`.

| Name | Description | Type | Required |
|---|---|---|---|
| `project_id` | GCP project ID to deploy into | `string` | yes |
| `producer_region` | Region for the producer VPC, subnet, router/NAT, and MIG | `string` | yes |
| `consumer_region` | Region for the consumer VPC, subnet, and consumer instance | `string` | yes |
| `domain` | Domain name(s) fronted by the load balancer | `list(string)` or `string` | yes |
| `dns_zone_name` | Name of the private Cloud DNS managed zone | `string` | yes |
| `dns_name` | DNS suffix for the private zone (must end with `.`) | `string` | yes |
| `vpc_network_self_links` | Self-links of VPCs granted visibility into the private zone | `list(string)` | yes |
| `record_name` | Fully-qualified name for the A record | `string` | yes |
| `ttl` | TTL (seconds) for the DNS A record | `number` | yes |

## Outputs

> Not defined in the excerpt reviewed; the following are commonly useful and
> recommended if not already present in `outputs.tf`:

| Name | Description |
|---|---|
| `lb_ip_address` | Public IP address of the load balancer (`module.lb.lb_ip_address`) |
| `producer_vpc_self_link` | Self-link of the producer VPC |
| `consumer_vpc_self_link` | Self-link of the consumer VPC |
| `mig_instance_group_self_link` | Self-link of the MIG's instance group |
| `dns_record_fqdn` | Fully-qualified name of the created A record |

## Usage

```bash
# 1. Authenticate
gcloud auth application-default login

# 2. Initialize
terraform init

# 3. Review the plan
terraform plan \
  -var="project_id=<your-project-id>" \
  -var="producer_region=us-central1" \
  -var="consumer_region=us-east1" \
  -var='domain=["example.com"]' \
  -var="dns_zone_name=internal-zone" \
  -var="dns_name=internal.example.com." \
  -var='vpc_network_self_links=["<producer-vpc-self-link>","<consumer-vpc-self-link>"]' \
  -var="record_name=app.internal.example.com." \
  -var="ttl=300"

# 4. Apply
terraform apply <same -var flags as above>
```

For repeatable deployments, move these values into a `terraform.tfvars` file
(excluded from version control if it contains secrets) or a per-environment
`*.auto.tfvars` file, and manage remote state (GCS backend with state
locking) rather than local state.

Example backend block to add:

```hcl
terraform {
  backend "gcs" {
    bucket = "<your-tf-state-bucket>"
    prefix = "producer-consumer-platform"
  }
}
```

## Security Considerations

Review and harden the following before treating this as production-ready:

- **Firewall rules are open to the internet.** All six firewall rules
  (HTTP/HTTPS/SSH on both VPCs) use `source_ranges = ["0.0.0.0/0"]`.
  - SSH (22) open to `0.0.0.0/0` is a significant exposure, especially since
    both VPCs' instances have no public IP anyway. Consider removing the SSH
    rules entirely and using **Identity-Aware Proxy (IAP) TCP forwarding**
    (`source_ranges = ["35.235.240.0/20"]`) or a bastion host instead.
  - HTTP/HTTPS (80/443) on the **consumer** VPC appear unnecessary since the
    consumer instance isn't fronted by the load balancer — confirm whether
    these rules are needed or should be removed to reduce attack surface.
- **Cloud Armor policy is enabled but unconfigured here.** `enable_cloud_armor = true`
  turns on the feature; verify the `load-balancer` module attaches a
  meaningful security policy (rate limiting, geo restrictions, OWASP rule
  sets) rather than an empty default-allow policy.
- **Service account scope.** The producer instance template's service account
  is limited to `logging.logWriter` and `monitoring.metricWriter`, which is
  good least-privilege practice — keep it that way and avoid adding broader
  roles (e.g., `roles/editor`) later.
- **`deletion_protection = false`** on the consumer instance means it can be
  destroyed without confirmation; enable protection for any instance holding
  state or serving production traffic.
- **VPC Peering route exposure.** Both peering resources import custom
  routes but don't export them (`export_custom_routes = false`), limiting
  blast radius — keep this asymmetry intentional and documented if it's a
  deliberate isolation boundary.
- **Startup scripts run as root and install packages unpinned** (`apt-get
  install -y nginx`). For production, pin package versions or bake a golden
  image via Packer to avoid drift and supply-chain risk from live `apt`
  installs at boot.
- **Image freshness.** The producer template pins
  `ubuntu-minimal-2604-resolute-amd64-v20260704` (a specific dated image),
  while the consumer instance pins an older
  `ubuntu-os-cloud/ubuntu-2004-focal-v20220712` image. Standardize on a
  single supported LTS release and establish a process for rotating image
  versions to pick up security patches.

## Cost Considerations

- The MIG autoscales between 1 and 5 `e2-medium` instances; size limits and
  scaling signals (CPU utilization, load balancing capacity, etc.) should be
  confirmed in the `mig` module to avoid unexpected scale-out costs.
- Cloud NAT and the global load balancer both carry hourly + usage-based
  charges independent of instance count.
- The consumer `e2-micro` instance is minimal cost but has no autoscaling or
  redundancy — treat it as a connectivity test harness, not a production
  workload.

## Known Limitations / TODOs

- A commented-out `google_compute_address.consumer_instance_address`
  resource suggests a static IP was considered for the consumer instance but
  isn't currently provisioned — remove the dead code or implement it if a
  static internal IP is required.
- Cloud NAT/Router is only provisioned for the **producer** VPC. If the
  consumer instance needs outbound internet access (e.g., for `apt-get
  update` during boot), add an equivalent router/NAT pair in
  `consumer-vpc`, or confirm connectivity is intentionally restricted to the
  peered network only.
- No `versions.tf` / provider version pinning was included in the reviewed
  file — pin `google` provider and Terraform core versions to avoid
  unexpected upstream changes.
- No explicit backend configuration — see the [Usage](#usage) section for a
  recommended GCS backend.

## Cleanup

```bash
terraform destroy <same -var flags used for apply>
```

Note that `google_compute_network_peering.consumer_to_producer_peering`
explicitly `depends_on` the reverse peering resource; Terraform will handle
ordering automatically on destroy, but if you ever manage peering outside
Terraform, tear down peerings before deleting either VPC.
