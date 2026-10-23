# Every taggable resource must say which environment it belongs to and that
# Terraform manages it, so console users know not to edit it by hand.
package terraform.policies.required_tags

import rego.v1

taggable := {"linode_instance", "linode_firewall", "linode_lke_cluster"}

deny contains msg if {
	some resource_type in taggable
	some rc in changes(resource_type)
	tags := object.get(rc.change.after, "tags", [])
	not "managed-by:terraform" in tags
	msg := sprintf("%s is missing the tag \"managed-by:terraform\"", [rc.address])
}

deny contains msg if {
	some resource_type in taggable
	some rc in changes(resource_type)
	tags := object.get(rc.change.after, "tags", [])
	env_tags := [t | some t in tags; startswith(t, "env:")]
	count(env_tags) == 0
	msg := sprintf("%s is missing an \"env:<environment>\" tag", [rc.address])
}

# Resource changes that create or update something. Deletes and no-ops are
# ignored so policies never block cleaning up non-compliant resources.
changes(resource_type) := [rc |
	some rc in input.plan.resource_changes
	rc.type == resource_type
	some action in rc.change.actions
	action in {"create", "update"}
]
