# ==========================================
# Core Instance Variables
# ==========================================

variable "project_id" {
  description = "The GCP project ID where the instance will be created."
  type        = string
  default     = null
}

variable "name" {
  description = "The name of the Compute Engine instance."
  type        = string
}

variable "description" {
  description = "A brief description of the instance."
  type        = string
  default     = null
}

variable "machine_type" {
  description = "The machine type to use for the instance (e.g., e2-medium, n2-standard-4)."
  type        = string
  default     = "e2-medium"
}

variable "zone" {
  description = "The GCP zone where the instance will be deployed."
  type        = string
}

variable "enable_display" {
  description = "Whether to enable virtual display on the instance."
  type        = bool
  default     = false
}

variable "desired_status" {
  description = "Desired status of the instance: RUNNING, SUSPENDED, or TERMINATED."
  type        = string
  default     = "RUNNING"
}

variable "hostname" {
  description = "A custom fully qualified domain name (FQDN) for the instance."
  type        = string
  default     = null
}

variable "resource_policies" {
  description = "List of resource policy self-links attached to the instance (e.g., snapshot schedules)."
  type        = list(string)
  default     = []
}

variable "can_ip_forward" {
  description = "Whether to allow IP forwarding on the instance."
  type        = bool
  default     = false
}

variable "min_cpu_platform" {
  description = "Minimum CPU platform for the instance (e.g., 'Intel Ice Lake')."
  type        = string
  default     = null
}

variable "metadata" {
  description = "Metadata key/value pairs available from within the instance."
  type        = map(string)
  default     = {}
}

variable "labels" {
  description = "Labels to apply to the instance."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Network tags applied to the instance for firewall rules and routing."
  type        = list(string)
  default     = []
}

variable "key_revocation_action_type" {
  description = "Action to take when a customer's encryption key is revoked ('STOP' or 'NONE')."
  type        = string
  default     = null
}

variable "metadata_startup_script" {
  description = "Startup script executed when the instance boots."
  type        = string
  default     = null
}

variable "deletion_protection" {
  description = "Whether deletion protection is enabled on the instance."
  type        = bool
  default     = true
}

variable "allow_stopping_for_update" {
  description = "If true, allows Terraform to stop the instance to update immutable parameters."
  type        = bool
  default     = true
}

# ==========================================
# Disks & Storage Blocks
# ==========================================

variable "boot_disk" {
  description = "Boot disk parameters."
  type = object({
    auto_delete       = optional(bool, true)
    device_name       = optional(string, null)
    mode              = optional(string, "READ_WRITE")
    kms_key_self_link = optional(string, null)
    image             = string
    size              = optional(number, 50)
    type              = optional(string, "pd-balanced")
    labels            = optional(map(string), {})
  })
}

variable "scratch_disk" {
  description = "Configuration for local SSD scratch disk."
  type = object({
    scratch_disk = optional(string, null) # Maps to device_name in block
    interface    = string                 # "NVME" or "SCSI"
    size         = optional(number, 375)
  })
  default = null
}

variable "attached_disks" {
  description = "List of additional persistent disks to attach to the instance."
  type = list(object({
    source                          = string
    device_name                     = optional(string, null)
    mode                            = optional(string, "READ_WRITE")
    disk_encryption_key_raw         = optional(string, null)
    disk_encryption_key_rsa         = optional(string, null)
    disk_encryption_service_account = optional(string, null)
    force_attach                    = optional(bool, false)
    kms_key_self_link               = optional(string, null)
  }))
  default = []
}

variable "instance_encryption_key" {
  description = "Encryption key used to encrypt boot/RAM operations."
  type = object({
    kms_key_self_link       = optional(string, null)
    kms_key_service_account = optional(string, null)
  })
  default = null
}

# ==========================================
# Networking
# ==========================================

variable "network_interfaces" {
  description = "Network configuration for the instance."
  type = list(object({
    network    = optional(string, null)
    subnetwork = optional(string, null)
    access_configs = optional(list(object({
      nat_ip = optional(string, null)
    })), [])
  }))
}

variable "network_performance_config" {
  description = "Configures total egress bandwidth tier for the instance."
  type = object({
    total_egress_bandwidth_tier = string # e.g., "TIER_1"
  })
  default = null
}

# ==========================================
# Compute & Hardware Configurations
# ==========================================

variable "scheduling" {
  description = "Scheduling and maintenance settings."
  type = object({
    automatic_restart           = optional(bool, true)
    on_host_maintenance         = optional(string, "MIGRATE")
    preemptible                 = optional(bool, false)
    provisioning_model          = optional(string, "STANDARD")
    instance_termination_action = optional(string, null)
    node_affinities = optional(list(object({
      key      = string
      operator = string
      values   = list(string)
    })), [])
  })
  default = null
}

variable "guest_accelerators" {
  description = "GPUs to attach to the instance."
  type = list(object({
    type  = string
    count = number
  }))
  default = []
}

variable "advanced_machine_features" {
  description = "Advanced hardware tuning flags."
  type = object({
    enable_nested_virtualization = optional(bool, null)
    threads_per_core             = optional(number, null)
    visible_core_count           = optional(number, null)
    enable_uefi_networking       = optional(bool, null)
    turbo_mode                   = optional(string, null)
    performance_monitoring_unit  = optional(string, null)
  })
  default = null
}

# ==========================================
# IAM, Security & Governance
# ==========================================

variable "service_account" {
  description = "Service account and OAuth scopes to attach to the VM."
  type = object({
    email  = string
    scopes = list(string)
  })
  default = null
}

variable "shielded_instance_config" {
  description = "Shielded VM security settings."
  type = object({
    enable_integrity_monitoring = optional(bool, true)
    enable_secure_boot          = optional(bool, true)
    enable_vtpm                 = optional(bool, true)
  })
  default = null
}

variable "confidential_instance_config" {
  description = "Confidential VM encryption settings."
  type = object({
    enable_confidential_compute = bool
    confidential_instance_type  = optional(string, null)
  })
  default = null
}

variable "params" {
  description = "Resource Manager Tags applied to the instance."
  type = object({
    resource_manager_tags = map(string)
  })
  default = null
}

variable "reservation_affinity" {
  description = "Reservation targeting strategy."
  type = object({
    type = string # "ANY_RESERVATION", "SPECIFIC_RESERVATION", or "NO_RESERVATION"
    specific_reservation = optional(object({
      key    = string
      values = list(string)
    }), null)
  })
  default = null
}