output "cluster_name"     { value = google_container_cluster.primary.name }
output "endpoint"         { value = google_container_cluster.primary.endpoint; sensitive = true }
output "cluster_id"       { value = google_container_cluster.primary.id }
output "node_pool_name"   { value = google_container_node_pool.primary_nodes.name }
output "ca_certificate"   { value = google_container_cluster.primary.master_auth[0].cluster_ca_certificate; sensitive = true }
