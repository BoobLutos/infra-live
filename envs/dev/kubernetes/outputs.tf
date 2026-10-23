output "cluster_id" {
  description = "ID of the dev LKE cluster."
  value       = module.kubernetes.cluster_id
}

output "cluster_label" {
  description = "Label of the dev LKE cluster (the platform workspace looks it up by this)."
  value       = module.kubernetes.cluster_label
}

output "kubeconfig_command" {
  description = "Command that writes the dev cluster's kubeconfig locally."
  value       = module.kubernetes.kubeconfig_command
}
