# Managed Instance Groups
resource "google_compute_instance_group_manager" "mig" {
  name = var.mig_name
  zone = "${var.location}-c"
  named_port {
    name = var.mig_named_port_name
    port = var.mig_named_port_port
  }
  version {
    instance_template = google_compute_instance_template.instance_template.id
    name              = var.template_name
  }
  base_instance_name = var.mig_base_instance_name
  target_size        = var.mig_target_size
}