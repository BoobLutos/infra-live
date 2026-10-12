# HCP Terraform OPA policy set definition.
# The free tier allows one policy set with up to five policies; this uses all five.
#
# mandatory = the run stops on violation (no override)
# advisory  = the run shows a warning but can continue

policy "allowed_regions" {
  query             = "data.terraform.policies.allowed_regions.deny"
  enforcement_level = "mandatory"
}

policy "allowed_instance_types" {
  query             = "data.terraform.policies.allowed_instance_types.deny"
  enforcement_level = "mandatory"
}

policy "required_tags" {
  query             = "data.terraform.policies.required_tags.deny"
  enforcement_level = "advisory"
}

policy "firewall_baseline" {
  query             = "data.terraform.policies.firewall_baseline.deny"
  enforcement_level = "mandatory"
}

policy "no_public_ssh" {
  query             = "data.terraform.policies.no_public_ssh.deny"
  enforcement_level = "mandatory"
}
