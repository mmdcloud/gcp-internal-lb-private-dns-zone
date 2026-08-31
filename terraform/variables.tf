variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = null
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
  description = "The DNS domain name for the zone, must end with a dot"
  type        = string
  default     = null
}

variable "ttl" {
  description = "TTL in seconds for the A record"
  type        = number
  default     = 300
}

variable "proxy_only_subnet_cidr" {
  description = "Proxy subnet cidr"
  type        = string
}