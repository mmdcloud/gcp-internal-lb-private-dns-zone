variable "project_id" {
  type        = string
  description = "The project ID to deploy to."
}

variable "region" {
  type        = string
  description = "The region to deploy to."
}

variable "type" {
  type        = string
  description = "NAT type: PUBLIC or PRIVATE."
  default     = "PUBLIC"
  validation {
    condition     = contains(["PUBLIC", "PRIVATE"], var.type)
    error_message = "Type must be either PUBLIC or PRIVATE."
  }
}

variable "nat_ip_allocate_option" {
  type        = string
  description = "Value can be AUTO_ONLY or MANUAL_ONLY."
  default     = null
  validation {
    condition     = var.nat_ip_allocate_option == null ? true : contains(["AUTO_ONLY", "MANUAL_ONLY"], var.nat_ip_allocate_option)
    error_message = "nat_ip_allocate_option must be AUTO_ONLY, MANUAL_ONLY, or null."
  }
}

variable "nat_ips" {
  type        = list(string)
  description = "List of self_links of external IPs for MANUAL_ONLY allocation."
  default     = []
}

variable "drain_nat_ips" {
  type        = list(string)
  description = "URLs of static external IPs assigned to the NAT to be drained."
  default     = []
}

variable "name" {
  type        = string
  description = "NAT name. Defaults to 'cloud-nat-RANDOM_SUFFIX'."
  default     = ""
}

variable "create_router" {
  type        = bool
  description = "Create router instead of using an existing one."
  default     = false
}

variable "router" {
  type        = string
  description = "Name of existing router or name for the new router."
}

variable "network" {
  type        = string
  description = "VPC network name; required if create_router is true."
  default     = ""
}

variable "router_asn" {
  type        = number
  description = "Router BGP ASN."
  default     = 64514
}

variable "router_keepalive_interval" {
  type        = number
  description = "Router BGP keepalive interval in seconds."
  default     = 20
}

variable "icmp_idle_timeout_sec" {
  type    = number
  default = 30
}

variable "tcp_established_idle_timeout_sec" {
  type    = number
  default = 1200
}

variable "tcp_transitory_idle_timeout_sec" {
  type    = number
  default = 30
}

variable "tcp_time_wait_timeout_sec" {
  type    = number
  default = 120
}

variable "udp_idle_timeout_sec" {
  type    = number
  default = 30
}

variable "min_ports_per_vm" {
  type        = number
  description = "Minimum ports per VM. Must be a power of 2 >= 32 if dynamic allocation is on."
  default     = null
}

variable "max_ports_per_vm" {
  type        = number
  description = "Maximum ports per VM when dynamic port allocation is enabled."
  default     = null
}

variable "enable_dynamic_port_allocation" {
  type    = bool
  default = false
}

variable "enable_endpoint_independent_mapping" {
  type    = bool
  default = false
}

variable "source_subnetwork_ip_ranges_to_nat" {
  type    = string
  default = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  validation {
    condition     = contains(["ALL_SUBNETWORKS_ALL_IP_RANGES", "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES", "LIST_OF_SUBNETWORKS"], var.source_subnetwork_ip_ranges_to_nat)
    error_message = "Valid values: ALL_SUBNETWORKS_ALL_IP_RANGES, ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES, LIST_OF_SUBNETWORKS."
  }
}

variable "subnetworks" {
  description = "Subnetwork NAT specifications."
  type = list(object({
    name                     = string
    source_ip_ranges_to_nat  = list(string)
    secondary_ip_range_names = optional(list(string), [])
  }))
  default = []
}

variable "log_config_enable" {
  type    = bool
  default = false
}

variable "log_config_filter" {
  type    = string
  default = "ALL"
  validation {
    condition     = contains(["ERRORS_ONLY", "TRANSLATIONS_ONLY", "ALL"], var.log_config_filter)
    error_message = "Valid values: ERRORS_ONLY, TRANSLATIONS_ONLY, ALL."
  }
}

variable "rules" {
  description = "NAT rules configurations."
  type = list(object({
    rule_number = number
    description = optional(string)
    match       = string
    action = object({
      source_nat_active_ips    = optional(list(string))
      source_nat_drain_ips     = optional(list(string))
      source_nat_active_ranges = optional(list(string))
      source_nat_drain_ranges  = optional(list(string))
    })
  }))
  default = []
}
