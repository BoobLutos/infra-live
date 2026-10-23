output "cluster_id" {
  description = "ID of the prod LKE cluster."
  value       = module.kubernetes.cluster_id
}

output "cluster_label" {
  description = "Label of the prod LKE cluster (the platform workspace looks it up by this)."
  value       = module.kubernetes.cluster_label
}

output "kubeconfig_command" {
  description = "Command that writes the prod cluster's kubeconfig locally."
  value       = module.kubernetes.kubeconfig_command
}
