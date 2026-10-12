# Values come from HCP Terraform workspace variables (set by hcp-bootstrap),
# so they can change without a code change and stay out of the repo.

variable "ssh_public_keys" {
  description = "SSH public keys allowed to log in as root."
  type        = list(string)
  default     = []
}

variable "admin_ssh_cidrs" {
  description = "IPv4 CIDRs allowed to reach SSH. Empty keeps SSH closed."
  type        = list(string)
  default     = []
}
