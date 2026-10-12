# Firewalls must deny inbound traffic by default, and every instance must be
# created behind a firewall.
package terraform.policies.firewall_baseline

import rego.v1

deny contains msg if {
	some rc in changes("linode_firewall")
	rc.change.after.inbound_policy != "DROP"
	msg := sprintf("%s has inbound_policy %q; it must be \"DROP\"", [rc.address, rc.change.after.inbound_policy])
}

# firewall_id is usually unknown at plan time (the firewall is created in the
# same run), which shows up in after_unknown. Only a value that is known to be
# empty is a violation.
deny contains msg if {
	some rc in changes("linode_instance")
	object.get(rc.change.after, "firewall_id", null) == null
	not object.get(rc.change, ["after_unknown", "firewall_id"], false)
	msg := sprintf("%s has no firewall_id; instances must be created behind a Cloud Firewall", [rc.address])
}

# Resource changes that create or update something. Deletes and no-ops are
# ignored so policies never block cleaning up non-compliant resources.
changes(resource_type) := [rc |
	some rc in input.plan.resource_changes
	rc.type == resource_type
	some action in rc.change.actions
	action in {"create", "update"}
]
