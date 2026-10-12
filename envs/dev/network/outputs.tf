output "vpc_id" {
  description = "ID of the dev VPC."
  value       = module.network.vpc_id
}

output "vpc_label" {
  description = "Label of the dev VPC (the app workspace looks it up by this)."
  value       = module.network.vpc_label
}

output "subnet_ids" {
  description = "Map of subnet label to subnet ID."
  value       = module.network.subnet_ids
}
