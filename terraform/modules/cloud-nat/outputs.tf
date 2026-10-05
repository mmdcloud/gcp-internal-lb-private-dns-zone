output "name" {
  description = "Name of the Cloud NAT"
  value       = local.name
}

output "nat_ip_allocate_option" {
  description = "NAT IP allocation mode"
  value       = local.nat_ip_allocate_option
}

output "region" {
  description = "Cloud NAT region"
  value       = google_compute_router_nat.main.region
}

output "router_name" {
  description = "Cloud NAT router name"
  value       = local.router
}

output "nat_id" {
  description = "The ID of the Cloud NAT gateway."
  value       = google_compute_router_nat.main.id
}

output "router_id" {
  description = "The ID of the Cloud Router (if created by module)."
  value       = var.create_router ? google_compute_router.router[0].id : null
}

output "router_self_link" {
  description = "The self_link of the Cloud Router (if created by module)."
  value       = var.create_router ? google_compute_router.router[0].self_link : null
}