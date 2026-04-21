output "vpc_id"             { value = google_compute_network.vpc.id }
output "vpc_self_link"      { value = google_compute_network.vpc.self_link }
output "subnet_id"          { value = google_compute_subnetwork.primary.id }
output "subnet_self_link"   { value = google_compute_subnetwork.primary.self_link }
output "pods_cidr_name"     { value = google_compute_subnetwork.primary.secondary_ip_range[0].range_name }
output "services_cidr_name" { value = google_compute_subnetwork.primary.secondary_ip_range[1].range_name }
output "nat_ip"             { value = google_compute_address.nat_ip.address }
output "router_name"        { value = google_compute_router.router.name }
