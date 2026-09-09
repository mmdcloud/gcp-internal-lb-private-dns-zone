resource "google_compute_instance" "instance" {
  name                       = var.name
  description                = var.description
  machine_type               = var.machine_type
  zone                       = var.zone
  project                    = var.project_id
  enable_display             = var.enable_display
  desired_status             = var.desired_status
  hostname                   = var.hostname
  resource_policies          = var.resource_policies
  can_ip_forward             = var.can_ip_forward
  min_cpu_platform           = var.min_cpu_platform
  metadata                   = var.metadata
  labels                     = var.labels
  tags                       = var.tags
  key_revocation_action_type = var.key_revocation_action_type
  metadata_startup_script    = var.metadata_startup_script
  deletion_protection        = var.deletion_protection
  allow_stopping_for_update  = var.allow_stopping_for_update

  dynamic "scheduling" {
    for_each = var.scheduling != null ? [var.scheduling] : []
    content {
      automatic_restart           = scheduling.value.automatic_restart
      on_host_maintenance         = scheduling.value.on_host_maintenance
      preemptible                 = scheduling.value.preemptible
      provisioning_model          = scheduling.value.provisioning_model
      instance_termination_action = scheduling.value.instance_termination_action

      dynamic "node_affinities" {
        for_each = scheduling.value.node_affinities
        content {
          key      = node_affinities.value.key
          operator = node_affinities.value.operator
          values   = node_affinities.value.values
        }
      }
    }
  }

  dynamic "scratch_disk" {
    for_each = var.scratch_disk != null ? [var.scratch_disk] : []
    content {
      device_name = scratch_disk.value.scratch_disk
      interface   = scratch_disk.value.interface
      size        = scratch_disk.value.size
    }
  }

  dynamic "service_account" {
    for_each = var.service_account != null ? [var.service_account] : []
    content {
      email  = service_account.value.email
      scopes = service_account.value.scopes
    }
  }

  dynamic "params" {
    for_each = var.params != null ? [var.params] : []
    content {
      resource_manager_tags = params.value.resource_manager_tags
    }
  }

  dynamic "shielded_instance_config" {
    for_each = var.shielded_instance_config != null ? [var.shielded_instance_config] : []
    content {
      enable_integrity_monitoring = shielded_instance_config.value.enable_integrity_monitoring
      enable_secure_boot          = shielded_instance_config.value.enable_secure_boot
      enable_vtpm                 = shielded_instance_config.value.enable_vtpm
    }
  }

  dynamic "network_interface" {
    for_each = var.network_interfaces
    content {
      network    = network_interface.value["network"]
      subnetwork = network_interface.value["subnetwork"]
      dynamic "access_config" {
        for_each = network_interface.value["access_configs"]
        content {
          nat_ip = access_config.value["nat_ip"]
        }
      }
    }
  }

  # Additional Persistent Disks
  dynamic "attached_disk" {
    for_each = var.attached_disks
    content {
      source                          = attached_disk.value.source
      device_name                     = attached_disk.value.device_name
      mode                            = attached_disk.value.mode
      disk_encryption_key_raw         = attached_disk.value.disk_encryption_key_raw
      disk_encryption_key_rsa         = attached_disk.value.disk_encryption_key_rsa
      disk_encryption_service_account = attached_disk.value.disk_encryption_service_account
      force_attach                    = attached_disk.value.force_attach
      kms_key_self_link               = attached_disk.value.kms_key_self_link
    }
  }

  # Confidential VM Configuration
  dynamic "confidential_instance_config" {
    for_each = var.confidential_instance_config != null ? [var.confidential_instance_config] : []
    content {
      enable_confidential_compute = confidential_instance_config.value.enable_confidential_compute
      confidential_instance_type  = confidential_instance_type.value.confidential_instance_type
    }
  }

  # Advanced CPU & Hardware Features
  dynamic "advanced_machine_features" {
    for_each = var.advanced_machine_features != null ? [var.advanced_machine_features] : []
    content {
      enable_nested_virtualization = advanced_machine_features.value.enable_nested_virtualization
      threads_per_core             = advanced_machine_features.value.threads_per_core
      visible_core_count           = advanced_machine_features.value.visible_core_count
      enable_uefi_networking       = advanced_machine_features.value.enable_uefi_networking
      turbo_mode                   = advanced_machine_features.value.turbo_mode
      performance_monitoring_unit  = advanced_machine_features.value.performance_monitoring_unit
    }
  }

  # GPU Attachments
  dynamic "guest_accelerator" {
    for_each = var.guest_accelerators
    content {
      type  = guest_accelerator.value.type
      count = guest_accelerator.value.count
    }
  }

  # Network Bandwidth Customization
  dynamic "network_performance_config" {
    for_each = var.network_performance_config != null ? [var.network_performance_config] : []
    content {
      total_egress_bandwidth_tier = network_performance_config.value.total_egress_bandwidth_tier
    }
  }

  # Sole Tenant / On-Demand Reservations
  dynamic "reservation_affinity" {
    for_each = var.reservation_affinity != null ? [var.reservation_affinity] : []
    content {
      type = reservation_affinity.value.type

      dynamic "specific_reservation" {
        for_each = reservation_affinity.value.specific_reservation != null ? [reservation_affinity.value.specific_reservation] : []
        content {
          key    = specific_reservation.value.key
          values = specific_reservation.value.values
        }
      }
    }
  }

  # Customer-Managed Encryption Key for CSEK Boot/RAM operations
  dynamic "instance_encryption_key" {
    for_each = var.instance_encryption_key != null ? [var.instance_encryption_key] : []
    content {
      kms_key_self_link       = instance_encryption_key.value.kms_key_self_link
      kms_key_service_account = instance_encryption_key.value.kms_key_service_account
    }
  }

  boot_disk {
    auto_delete       = var.boot_disk.auto_delete
    device_name       = var.boot_disk.device_name
    mode              = var.boot_disk.mode
    kms_key_self_link = var.boot_disk.kms_key_self_link

    initialize_params {
      image  = var.boot_disk.image
      size   = var.boot_disk.size
      type   = var.boot_disk.type
      labels = var.boot_disk.labels
    }
  }
}