config {
  call_module_type = "none"
}

# The bundled Terraform ruleset (there is no Linode-specific tflint ruleset).
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
}
