project_id = "encoded-alpha-457108-e8"

producer_region = "us-central1"
consumer_region = "us-central1"

image_family  = "ubuntu-2404-lts-amd64"
image_project = "ubuntu-os-cloud"

producer_vpc_name = "producer-vpc"
mig_subnet_name   = "mig-subnet"
mig_subnet_cidr   = "10.1.10.0/24"
lb_subnet_name    = "lb-subnet"
lb_subnet_cidr    = "10.1.20.0/24"
# Must be /23 or larger and must NOT overlap mig-subnet or lb-subnet above.
proxy_only_subnet_cidr     = "10.1.30.0/23"
producer_instance_tag      = "producer-instance"
health_check_source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
http_port                  = "80"
iap_ssh_source_ranges      = ["35.235.240.0/20"]
ssh_port                   = "22"

consumer_vpc_name     = "consumer-vpc"
consumer_subnet_name  = "consumer-subnet"
consumer_subnet_cidr  = "10.2.0.0/24"
consumer_instance_tag = "consumer-instance"

router_name     = "router"
router_nat_name = "router-nat"

peering_producer_to_consumer_name = "producer-consumer"
peering_consumer_to_producer_name = "consumer-producer"

instance_template_name_prefix  = "producer-instance-template"
instance_template_machine_type = "e2-medium"
boot_disk_size_gb              = 50
boot_disk_type                 = "pd-balanced"
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
common_labels = {
  team = "platform"
}

mig_name                      = "mig"
mig_named_port_name           = "http"
mig_named_port_number         = 80
mig_health_check_type         = "HTTP"
mig_health_check_port         = 80
mig_health_check_request_path = "/"
mig_autoscaling_min_replicas  = 2
mig_autoscaling_max_replicas  = 5

lb_name                    = "internal-lb"
lb_type                    = "INTERNAL"
lb_backend_protocol        = "HTTP"
lb_backend_port_name       = "http"
lb_balancing_mode          = "UTILIZATION"
lb_capacity_scaler         = 1.0
lb_max_utilization         = 0.8
lb_allow_global_access     = true
lb_enable_ssl              = false
lb_enable_http             = true
lb_managed_ssl_certificate = false
lb_enable_cloud_armor      = false

dns_zone_name        = "internal-zone"
dns_zone_description = "Private DNS zone managed by Terraform"
dns_name             = "mohitd.xyz"
dns_record_prefix    = "internal"
dns_record_type      = "A"
ttl                  = 300

consumer_instance_name                      = "consumer-instance"
consumer_instance_machine_type              = "e2-micro"
consumer_instance_zone_suffix               = "-a"
consumer_instance_deletion_protection       = false
consumer_instance_allow_stopping_for_update = true