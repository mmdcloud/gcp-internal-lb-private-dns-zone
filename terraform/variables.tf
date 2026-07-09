variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "producer_region" {
  description = "Default region (used only if needed elsewhere)"
  type        = string
  default     = "asia-south1"
}

variable "consumer_region" {
  description = "Default region (used only if needed elsewhere)"
  type        = string
  default     = "asia-south2"
}

variable "dns_zone_name" {
  description = "Terraform resource / Cloud DNS zone name (must be unique per project)"
  type        = string
  default     = "internal-private-zone"
}

variable "dns_name" {
  description = "The DNS domain name for the zone, must end with a dot, e.g. internal.example.com."
  type        = string
  default     = "internal.example.com."
}

variable "record_name" {
  description = "Fully qualified name for the A record, must end with a dot"
  type        = string
  default     = "app.internal.example.com."
}

variable "record_ip" {
  description = "IP address for the A record"
  type        = string
  default     = "10.10.10.10"
}

variable "ttl" {
  description = "TTL in seconds for the A record"
  type        = number
  default     = 300
}

# List of existing VPC self_links to attach to the private zone
variable "vpc_network_self_links" {
  description = "List of VPC network self_links to authorize for this private zone"
  type        = list(string)
  default     = []
}