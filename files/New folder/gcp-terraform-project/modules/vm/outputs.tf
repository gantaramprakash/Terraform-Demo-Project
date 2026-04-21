output "instance_name" { value = google_compute_instance.app_vm.name }
output "internal_ip"   { value = google_compute_instance.app_vm.network_interface[0].network_ip }
output "instance_id"   { value = google_compute_instance.app_vm.instance_id }
output "self_link"     { value = google_compute_instance.app_vm.self_link }
