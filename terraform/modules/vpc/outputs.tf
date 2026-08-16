output "self_link" {
  value = google_compute_network.vpc.self_link
}

output "vpc_name" {
  value = google_compute_network.vpc.name
}

output "vpc_id" {
  value = google_compute_network.vpc.id
}

output "subnets" {
  value = google_compute_subnetwork.subnets[*]
}

output "subnets_by_name" {
  description = "Map of subnet name -> subnet object"
  value       = { for s in google_compute_subnetwork.subnets : s.name => s }
}