############################################
# Core
############################################
variable "project_id" {
  description = "GCP project ID where all resources will be created."
  type        = string
}

variable "producer_region" {
  description = "Region for the producer VPC (MIG, LB subnet, NAT, router)."
  type        = string
  default     = "us-central1"
}

variable "consumer_region" {
  description = "Region for the consumer VPC and consumer instance."
  type        = string
  default     = "us-central1"
}

############################################
# Boot image
############################################
variable "image_family" {
  description = "Source image family for compute instances."
  type        = string
  default     = "ubuntu-2404-lts-amd64"
}

variable "image_project" {
  description = "Project that owns the source image family."
  type        = string
  default     = "ubuntu-os-cloud"
}

############################################
# Producer VPC / subnets
############################################
variable "producer_vpc_name" {
  description = "Name of the producer VPC."
  type        = string
  default     = "producer-vpc"
}

variable "mig_subnet_name" {
  description = "Name of the subnet hosting the MIG instances."
  type        = string
  default     = "mig-subnet"
}

variable "mig_subnet_cidr" {
  description = "CIDR range for the MIG subnet."
  type        = string
  default     = "10.1.10.0/24"
}

variable "lb_subnet_name" {
  description = "Name of the subnet hosting the internal load balancer."
  type        = string
  default     = "lb-subnet"
}

variable "lb_subnet_cidr" {
  description = "CIDR range for the LB subnet."
  type        = string
  default     = "10.1.20.0/24"
}

variable "proxy_only_subnet_cidr" {
  description = "CIDR range for the regional proxy-only subnet required by the INTERNAL_MANAGED load balancer. Must be /23 or larger and not overlap other producer VPC subnets."
  type        = string
  default     = "10.1.30.0/23"
}

variable "producer_instance_tag" {
  description = "Network tag applied to producer instances and matched by producer VPC firewall rules."
  type        = string
  default     = "producer-instance"
}

variable "health_check_source_ranges" {
  description = "Source IP ranges allowed to reach producer instances on the HTTP port (proxy-only subnet + GCP health check ranges)."
  type        = list(string)
  default     = ["130.211.0.0/22", "35.191.0.0/16"]
}

variable "http_port" {
  description = "TCP port the producer VPC firewall opens for HTTP traffic."
  type        = string
  default     = "80"
}

variable "iap_ssh_source_ranges" {
  description = "Source IP range for IAP TCP forwarding, used to allow SSH into instances via IAP."
  type        = list(string)
  default     = ["35.235.240.0/20"]
}

variable "ssh_port" {
  description = "TCP port opened for SSH access via IAP."
  type        = string
  default     = "22"
}

############################################
# Consumer VPC / subnet
############################################
variable "consumer_vpc_name" {
  description = "Name of the consumer VPC."
  type        = string
  default     = "consumer-vpc"
}

variable "consumer_subnet_name" {
  description = "Name of the consumer subnet."
  type        = string
  default     = "consumer-subnet"
}

variable "consumer_subnet_cidr" {
  description = "CIDR range for the consumer subnet."
  type        = string
  default     = "10.2.0.0/24"
}

variable "consumer_instance_tag" {
  description = "Network tag applied to the consumer instance and matched by consumer VPC firewall rules."
  type        = string
  default     = "consumer-instance"
}

############################################
# Router / NAT
############################################
variable "router_name" {
  description = "Name of the Cloud Router in the producer VPC."
  type        = string
  default     = "router"
}

variable "router_nat_name" {
  description = "Name of the Cloud NAT gateway."
  type        = string
  default     = "router-nat"
}

############################################
# VPC peering
############################################
variable "peering_producer_to_consumer_name" {
  description = "Name of the producer -> consumer VPC peering connection."
  type        = string
  default     = "producer-consumer"
}

variable "peering_consumer_to_producer_name" {
  description = "Name of the consumer -> producer VPC peering connection."
  type        = string
  default     = "consumer-producer"
}

############################################
# Instance template
############################################
variable "instance_template_name_prefix" {
  description = "Name prefix for the producer instance template."
  type        = string
  default     = "producer-instance-template"
}

variable "instance_template_machine_type" {
  description = "Machine type for producer instances."
  type        = string
  default     = "e2-medium"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size (GB) for producer instances."
  type        = number
  default     = 50
}

variable "boot_disk_type" {
  description = "Boot disk type for producer instances."
  type        = string
  default     = "pd-balanced"
}

variable "service_account_roles" {
  description = "IAM roles granted to the producer instance's service account."
  type        = list(string)
  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ]
}

variable "startup_script" {
  description = "Startup script run on producer instances."
  type        = string
  default     = <<-EOT
    #!/bin/bash
    set -euo pipefail
    sudo apt-get update
    sudo apt-get install -y nginx
    echo "Hello World from $(hostname -f)" > /var/www/html/index.html
  EOT
}

variable "common_labels" {
  description = "Labels applied to the instance template and MIG."
  type        = map(string)
  default = {
    team = "platform"
  }
}

############################################
# MIG
############################################
variable "mig_name" {
  description = "Name of the managed instance group."
  type        = string
  default     = "mig"
}

variable "mig_named_port_name" {
  description = "Name of the MIG named port."
  type        = string
  default     = "http"
}

variable "mig_named_port_number" {
  description = "Port number of the MIG named port."
  type        = number
  default     = 80
}

variable "mig_health_check_type" {
  description = "Protocol used for the MIG health check."
  type        = string
  default     = "HTTP"
}

variable "mig_health_check_port" {
  description = "Port used for the MIG health check."
  type        = number
  default     = 80
}

variable "mig_health_check_request_path" {
  description = "Request path used for the MIG HTTP(S) health check."
  type        = string
  default     = "/"
}

variable "mig_autoscaling_min_replicas" {
  description = "Minimum number of MIG instances."
  type        = number
  default     = 2
}

variable "mig_autoscaling_max_replicas" {
  description = "Maximum number of MIG instances."
  type        = number
  default     = 5
}

############################################
# Load balancer
############################################
variable "lb_name" {
  description = "Name of the load balancer."
  type        = string
  default     = "internal-lb"
}

variable "lb_type" {
  description = "Load balancer type. INTERNAL for a regional internal HTTP(S) LB, EXTERNAL for a global external one."
  type        = string
  default     = "INTERNAL"
}

variable "lb_backend_protocol" {
  description = "Protocol used by the LB backend service."
  type        = string
  default     = "HTTP"
}

variable "lb_backend_port_name" {
  description = "Named port on the backend instance group that the LB forwards to."
  type        = string
  default     = "http"
}

variable "lb_balancing_mode" {
  description = "Balancing mode for the LB backend group (UTILIZATION, RATE, or CONNECTION)."
  type        = string
  default     = "UTILIZATION"
}

variable "lb_capacity_scaler" {
  description = "Capacity multiplier (0.0-1.0) for the LB backend group."
  type        = number
  default     = 1.0
}

variable "lb_max_utilization" {
  description = "Target CPU/utilization for the LB backend group when balancing_mode = UTILIZATION."
  type        = number
  default     = 0.8
}

variable "lb_allow_global_access" {
  description = "Whether clients from any region can reach the internal LB."
  type        = bool
  default     = true
}

variable "lb_enable_ssl" {
  description = "Whether to provision an HTTPS listener on the LB."
  type        = bool
  default     = false
}

variable "lb_enable_http" {
  description = "Whether to provision an HTTP listener on the LB."
  type        = bool
  default     = true
}

variable "lb_managed_ssl_certificate" {
  description = "Whether to provision a Google-managed SSL certificate (EXTERNAL LB only)."
  type        = bool
  default     = false
}

variable "lb_enable_cloud_armor" {
  description = "Whether to attach a Cloud Armor security policy (EXTERNAL LB only)."
  type        = bool
  default     = false
}

############################################
# Private DNS
############################################
variable "dns_zone_name" {
  description = "Name of the private Cloud DNS managed zone (GCP resource name, not the domain)."
  type        = string
  default     = "internal-zone"
}

variable "dns_zone_description" {
  description = "Description of the private DNS zone."
  type        = string
  default     = "Private DNS zone managed by Terraform"
}

variable "dns_name" {
  description = "DNS suffix for the private zone, e.g. 'internal.example.com'. A trailing dot is added automatically."
  type        = string
  default     = "internal.example.com"
}

variable "dns_record_prefix" {
  description = "Hostname label prepended to the DNS zone name to form the A record's FQDN."
  type        = string
  default     = "internal"
}

variable "dns_record_type" {
  description = "DNS record type for the LB record."
  type        = string
  default     = "A"
}

variable "ttl" {
  description = "TTL (seconds) for the DNS A record pointing at the internal load balancer."
  type        = number
  default     = 300
}

############################################
# Consumer instance
############################################
variable "consumer_instance_name" {
  description = "Name of the consumer compute instance."
  type        = string
  default     = "consumer-instance"
}

variable "consumer_instance_machine_type" {
  description = "Machine type for the consumer instance."
  type        = string
  default     = "e2-micro"
}

variable "consumer_instance_zone_suffix" {
  description = "Zone suffix appended to consumer_region to form the instance's zone, e.g. '-a'."
  type        = string
  default     = "-a"
}

variable "consumer_instance_deletion_protection" {
  description = "Whether deletion protection is enabled on the consumer instance. Should be true in production."
  type        = bool
  default     = false
}

variable "consumer_instance_allow_stopping_for_update" {
  description = "Whether Terraform is allowed to stop the consumer instance to apply updates."
  type        = bool
  default     = true
}