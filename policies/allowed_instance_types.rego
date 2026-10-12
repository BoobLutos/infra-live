# Only small shared-CPU plans are allowed during the pilot, to cap cost.
package terraform.policies.allowed_instance_types

import rego.v1

allowed := {"g6-nanode-1", "g6-standard-1"}

deny contains msg if {
	some rc in changes("linode_instance")
	plan_type := rc.change.after.type
	not plan_type in allowed
	msg := sprintf("%s uses plan %q; allowed plans are %v", [rc.address, plan_type, sort(allowed)])
}

# Resource changes that create or update something. Deletes and no-ops are
# ignored so policies never block cleaning up non-compliant resources.
changes(resource_type) := [rc |
	some rc in input.plan.resource_changes
	rc.type == resource_type
	some action in rc.change.actions
	action in {"create", "update"}
]
