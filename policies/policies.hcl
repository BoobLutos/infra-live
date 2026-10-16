# HCP Terraform OPA policy set definition.
# Free-tier limits: one policy set, and only ONE mandatory policy. All blocking
# rules are therefore combined in mandatory.rego; the rest are advisory.
#
# mandatory = the run stops on violation (no override)
# advisory  = the run shows a warning but can continue
#
# hcp-bootstrap uploads these (the free tier can't sync policy sets from Git).

policy "mandatory" {
  query             = "data.terraform.policies.mandatory.deny"
  enforcement_level = "mandatory"
}

policy "required_tags" {
  query             = "data.terraform.policies.required_tags.deny"
  enforcement_level = "advisory"
}
