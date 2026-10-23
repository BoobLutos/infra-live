# Values come from the "platform-settings" HCP Terraform variable set (set by
# hcp-bootstrap), so secrets stay out of the repo.

variable "acme_email" {
  description = "Email Let's Encrypt sends certificate expiry notices to."
  type        = string
}

variable "smtp_user" {
  description = "Brevo SMTP login n8n sends password-reset emails with."
  type        = string
}

variable "smtp_password" {
  description = "Brevo SMTP key."
  type        = string
  sensitive   = true
}

variable "smtp_sender" {
  description = "Verified sender address for n8n's emails."
  type        = string
}

variable "n8n_encryption_key" {
  description = "n8n credentials encryption key. Leave unset on a fresh install; set it (as a sensitive workspace variable) only when restoring an existing n8n database."
  type        = string
  default     = null
  sensitive   = true
}
