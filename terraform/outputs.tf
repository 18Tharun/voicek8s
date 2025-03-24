output "cluster_id" {
  value = digitalocean_kubernetes_cluster.voice_ai_cluster.id
}

output "kubernetes_endpoint" {
  value = digitalocean_kubernetes_cluster.voice_ai_cluster.endpoint
}

output "kubeconfig" {
  value     = digitalocean_kubernetes_cluster.voice_ai_cluster.kube_config.0.raw_config
  sensitive = true
}

output "droplet_id" {
  value = digitalocean_droplet.voice_ai_server.id
}

output "droplet_ip" {
  value = digitalocean_reserved_ip.voice_ai_ip.ip_address
}

output "domain_name" {
  value = var.domain_name != "" ? "https://${var.domain_name}" : "http://${digitalocean_reserved_ip.voice_ai_ip.ip_address}"
}

output "registry_url" {
  value = digitalocean_container_registry.voice_ai_registry.endpoint
}

output "ssh_command" {
  value = "ssh root@${digitalocean_reserved_ip.voice_ai_ip.ip_address}"
}
