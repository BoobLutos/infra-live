# Keep resources in approved EU regions (data residency + cost control).
package terraform.policies.allowed_regions

import rego.v1

allowed := {"se-sto", "eu-central"}

regional_types := {"linode_instance", "linode_vpc"}

deny contains msg if {
	some resource_type in regional_types
	some rc in changes(resource_type)
	region := rc.change.after.region
	not region in allowed
	msg := sprintf("%s uses region %q; allowed regions are %v", [rc.address, region, sort(allowed)])
}

# Resource changes that create or update something. Deletes and no-ops are
# ignored so policies never block cleaning up non-compliant resources.
changes(resource_type) := [rc |
	some rc in input.plan.resource_changes
	rc.type == resource_type
	some action in rc.change.actions
	action in {"create", "update"}
]
