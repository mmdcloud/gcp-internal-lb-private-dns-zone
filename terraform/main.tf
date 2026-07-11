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

  name_prefix       = "app-web"
  machine_type      = "e2-standard-4"
  source_image      = "projects/debian-cloud/global/images/family/debian-12"
  boot_disk_size_gb = 50
  boot_disk_type    = "pd-balanced"

  subnetwork       = module.producer_vpc.subnets[0].self_link
  assign_public_ip = false
  network_tags     = ["app-web", "http-server"]

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
  name       = "web"
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
    min_replicas = 2
    max_replicas = 6
  }

  labels = {
    env = "dev"
  }
}

# -----------------------------------------------------------------------------------------
# Load Balancer
# -----------------------------------------------------------------------------------------
module "lb" {
  source                                  = "./modules/load-balancer"
  forwarding_port_range                   = "80"
  forwarding_rule_name                    = "frontend-global-forwarding-rule"
  forwarding_scheme                       = "EXTERNAL"
  global_address_type                     = "EXTERNAL"
  url_map_name                            = "frontend-url-map"
  global_address_name                     = "frontend-lb-global-address"
  target_proxy_name                       = "frontend-target-proxy"
  backend_service_name                    = "frontend-service"
  backend_service_enable_cdn              = false
  backend_service_port_name               = "frontend-port"
  backend_service_protocol                = "HTTP"
  backend_service_timeout_sec             = 10
  backend_service_load_balancing_scheme   = "EXTERNAL"
  backend_service_custom_request_headers  = ["X-Client-Geo-Location: {client_region_subdivision}, {client_city}"]
  backend_service_custom_response_headers = ["X-Cache-Hit: {cdn_cache_status}"]
  backend_service_health_checks           = [module.carshub_frontend_instance.health_check_id]
  # security_policy                         = module.cloud_armor.policy.id
  backend_service_backends = [
    {
      group           = "${module.carshub_frontend_instance.instance_group}"
      balancing_mode  = "UTILIZATION"
      capacity_scaler = 1.0
    }
  ]
}

# --------------------------------------------------------------------------
# Private DNS Zone
# --------------------------------------------------------------------------
resource "google_dns_managed_zone" "private_zone" {
  project     = var.project_id
  name        = var.dns_zone_name
  dns_name    = var.dns_name
  description = "Private DNS zone managed by Terraform"
  visibility  = "private"
  private_visibility_config {
    dynamic "networks" {
      for_each = var.vpc_network_self_links
      content {
        network_url = networks.value
      }
    }
  }
}

resource "google_dns_record_set" "record" {
  project      = var.project_id
  name         = var.record_name
  type         = "A"
  ttl          = var.ttl
  managed_zone = google_dns_managed_zone.private_zone.name

  rrdatas = [module.lb.address]
}

# --------------------------------------------------------------------------
# Compute Instances
# --------------------------------------------------------------------------

# Consumer Instance
resource "google_compute_address" "consumer_instance_address" {
  name = "consumer-instance-address"
}

module "consumer_instance" {
  source                    = "./modules/compute"
  name                      = "consumer-instance"
  machine_type              = "e2-micro"
  zone                      = var.consumer_region
  metadata_startup_script   = "sudo apt-get update; sudo apt-get install nginx -y"
  deletion_protection       = false
  allow_stopping_for_update = true
  image                     = "ubuntu-os-cloud/ubuntu-2004-focal-v20220712"
  network_interfaces = [
    {
      network    = "${module.consumer_vpc.vpc_id}"
      subnetwork = "${module.consumer_vpc.subnets[0].id}"
      access_configs = [
        {
          nat_ip = "${google_compute_address.consumer_instance_address.address}"
        }
      ]
    }
  ]
  tags = ["consumer-instance"]
}
