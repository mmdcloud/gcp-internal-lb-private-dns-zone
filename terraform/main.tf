# --------------------------------------------------------------------------
# Data resource blocks
# --------------------------------------------------------------------------
data "google_project" "project" {}

# --------------------------------------------------------------------------
# VPC Configuration
# --------------------------------------------------------------------------
module "producer_vpc" {
  source                          = "./modules/vpc"
  vpc_name                        = "producer-vpc"
  delete_default_routes_on_create = false
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  subnets = [
    {
      name                     = "producer-subnet"
      region                   = var.producer_region
      purpose                  = "PRIVATE"
      role                     = "ACTIVE"
      private_ip_google_access = true
      ip_cidr_range            = "10.1.0.0/24"
    }
  ]
  firewall_data = [
    {
      name          = "producer-vpc-firewall-http"
      target_tags   = ["producer-instance"]
      source_ranges = ["0.0.0.0/0"]
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["80"]
        }
      ]
    },
    {
      name          = "producer-vpc-firewall-https"
      target_tags   = ["producer-instance"]
      source_ranges = ["0.0.0.0/0"]
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["443"]
        }
      ]
    },
    {
      name          = "producer-vpc-firewall-ssh"
      target_tags   = ["producer-instance"]
      source_ranges = ["0.0.0.0/0"]
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]
    }
  ]
}

module "consumer_vpc" {
  source                          = "./modules/vpc"
  vpc_name                        = "consumer-vpc"
  delete_default_routes_on_create = false
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  subnets = [
    {
      name                     = "consumer-subnet"
      region                   = var.consumer_region
      purpose                  = "PRIVATE"
      role                     = "ACTIVE"
      private_ip_google_access = true
      ip_cidr_range            = "10.2.0.0/24"
    }
  ]
  firewall_data = [
    {
      name          = "consumer-vpc-firewall-http"
      target_tags   = ["consumer-instance"]
      source_ranges = ["0.0.0.0/0"]
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["80"]
        }
      ]
    },
    {
      name          = "consumer-vpc-firewall-https"
      target_tags   = ["consumer-instance"]
      source_ranges = ["0.0.0.0/0"]
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["443"]
        }
      ]
    },
    {
      name          = "consumer-vpc-firewall-ssh"
      target_tags   = ["consumer-instance"]
      source_ranges = ["0.0.0.0/0"]
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]
    }
  ]
}

# --------------------------------------------------------------------------
# NAT Gateway and Cloud Router Configuration  
# --------------------------------------------------------------------------
resource "google_compute_router" "router" {
  name    = "router"
  region  = var.producer_region
  network = module.producer_vpc.self_link
}

resource "google_compute_router_nat" "router_nat" {
  name                               = "router-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  type                               = "PUBLIC"
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# --------------------------------------------------------------------------
# VPC Network Peering
# --------------------------------------------------------------------------
resource "google_compute_network_peering" "producer_to_consumer_peering" {
  name                 = "producer-consumer"
  network              = module.producer_vpc.self_link
  peer_network         = module.consumer_vpc.self_link
  export_custom_routes = false
  import_custom_routes = true
}

resource "google_compute_network_peering" "consumer_to_producer_peering" {
  name                 = "consumer-producer"
  network              = module.consumer_vpc.self_link
  peer_network         = module.producer_vpc.self_link
  export_custom_routes = false
  import_custom_routes = true

  depends_on = [google_compute_network_peering.producer_to_consumer_peering]
}

# -----------------------------------------------------------------------------------------
# Instance template
# -----------------------------------------------------------------------------------------
module "instance_template" {
  source = "./modules/instance-template"

  region     = var.producer_region
  project_id = data.google_project.project.project_id

  name_prefix       = "producer-instance-template"
  machine_type      = "e2-medium"
  source_image      = "ubuntu-minimal-2604-resolute-amd64-v20260704"
  boot_disk_size_gb = 50
  boot_disk_type    = "pd-balanced"

  network          = module.producer_vpc.self_link
  subnetwork       = module.producer_vpc.subnets[0].self_link
  assign_public_ip = false
  network_tags     = ["producer-instance"]

  create_service_account = true
  service_account_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ]

  startup_script = <<-EOT
    #!/bin/bash
    set -euo pipefail
    sudo apt-get update
    sudo apt-get install -y nginx
    echo "Hello World from $(hostname -f)" > /var/www/html/index.html
  EOT

  labels = {
    environment = "production"
    team        = "platform"
  }
}

# -----------------------------------------------------------------------------------------
# MIG Configuration
# -----------------------------------------------------------------------------------------
module "mig" {
  source = "./modules/mig"

  project_id = var.project_id
  name       = "mig"
  region     = var.producer_region

  instance_template = module.instance_template.self_link_unique

  named_ports = [
    { name = "http", port = 80 }
  ]

  health_check = {
    type         = "HTTP"
    port         = 80
    request_path = "/"
  }

  autoscaling = {
    min_replicas = 1
    max_replicas = 5
  }

  labels = {
    env = "dev"
  }
}

# -----------------------------------------------------------------------------------------
# Load Balancer
# -----------------------------------------------------------------------------------------
module "lb" {
  source = "./modules/load-balancer"

  project_id = var.project_id
  name       = "lb"
  backends = {
    lb = {
      is_default          = true
      protocol            = "HTTP"
      port_name           = "http"
      health_check_id     = module.mig.health_check_id
      manage_health_check = false
      groups = [
        { group = module.mig.instance_group_self_link }
      ]
    }
  }

  enable_cloud_armor   = false
  enable_http_redirect = false
}

# --------------------------------------------------------------------------
# Private DNS Zone
# --------------------------------------------------------------------------
# resource "google_dns_managed_zone" "private_zone" {
#   project     = var.project_id
#   name        = var.dns_zone_name
#   dns_name    = "${var.dns_name}."
#   description = "Private DNS zone managed by Terraform"
#   visibility  = "private"
#   private_visibility_config {
#     networks {
#       network_url = module.consumer_vpc.self_link
#     }
#     networks {
#       network_url = module.producer_vpc.self_link
#     }
#     # dynamic "networks" {
#     #   for_each = var.vpc_network_self_links
#     #   content {
#     #     network_url = networks.value
#     #   }
#     # }
#   }
#   depends_on = [module.lb]
# }

# resource "google_dns_record_set" "record" {
#   project      = var.project_id
#   name         = var.record_name
#   type         = "A"
#   ttl          = var.ttl
#   managed_zone = google_dns_managed_zone.private_zone.name

#   rrdatas = [module.lb.lb_ip_address]
# }

# --------------------------------------------------------------------------
# Compute Instances
# --------------------------------------------------------------------------

# Consumer Instance
# resource "google_compute_address" "consumer_instance_address" {
#   name = "consumer-instance-address"
#   region = var.consumer_region
# }

module "consumer_instance" {
  source                    = "./modules/compute"
  name                      = "consumer-instance"
  machine_type              = "e2-micro"
  zone                      = "${var.consumer_region}-a"
  metadata_startup_script   = "sudo apt-get update; sudo apt-get install nginx -y"
  deletion_protection       = false
  allow_stopping_for_update = true
  image                     = "ubuntu-os-cloud/ubuntu-2004-focal-v20220712"
  network_interfaces = [
    {
      network        = "${module.consumer_vpc.vpc_id}"
      subnetwork     = "${module.consumer_vpc.subnets[0].id}"
      access_configs = []
    }
  ]
  tags = ["consumer-instance"]
}