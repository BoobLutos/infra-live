output "instance_id" {
  description = "ID of the web server."
  value       = module.web.instance_id
}

output "public_ipv4" {
  description = "Public IPv4 address(es) of the web server."
  value       = module.web.public_ipv4
}
