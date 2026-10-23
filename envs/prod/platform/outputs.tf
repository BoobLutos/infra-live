output "ingress_ip" {
  description = "IP of the ingress NodeBalancer. Point the prod DNS A records here."
  value       = module.platform.ingress_ip
}

output "argocd_url" {
  description = "Argo CD URL."
  value       = module.platform.argocd_url
}

output "n8n_url" {
  description = "n8n URL."
  value       = module.platform.n8n_url
}
