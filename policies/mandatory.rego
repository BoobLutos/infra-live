# Mandatory guardrails for the Linode pilot. Any message in `deny` blocks the run.
#
# HCP Terraform's free tier allows only ONE mandatory policy, so all blocking
# rules live together in this file. Advisory rules (warnings only) live in their
# own files, e.g. required_tags.rego.
package terraform.policies.mandatory

import rego.v1

# --- 1. Allowed regions: keep resources in approved EU regions --------------

allowed_regions := {"se-sto", "eu-central"}

regional_types := {"linode_instance", "linode_vpc", "linode_lke_cluster"}

deny contains msg if {
	some resource_type in regional_types
	some rc in changes(resource_type)
	region := rc.change.after.region
	not region in allowed_regions
	msg := sprintf("[allowed-regions] %s uses region %q; allowed regions are %v", [rc.address, region, sort(allowed_regions)])
}

# --- 2. Allowed instance types: only small shared-CPU plans, to cap cost ----

allowed_instance_types := {"g6-nanode-1", "g6-standard-1"}

deny contains msg if {
	some rc in changes("linode_instance")
	plan_type := rc.change.after.type
	not plan_type in allowed_instance_types
	msg := sprintf("[allowed-instance-types] %s uses plan %q; allowed plans are %v", [rc.address, plan_type, sort(allowed_instance_types)])
}

# LKE worker nodes are Linode instances too, so node pools follow the same list.
deny contains msg if {
	some rc in changes("linode_lke_cluster")
	some pool in object.get(rc.change.after, "pool", [])
	not pool.type in allowed_instance_types
	msg := sprintf("[allowed-instance-types] %s has a node pool of plan %q; allowed plans are %v", [rc.address, pool.type, sort(allowed_instance_types)])
}

# --- 3. Firewall baseline: deny-by-default, and every instance behind one ---

deny contains msg if {
	some rc in changes("linode_firewall")
	rc.change.after.inbound_policy != "DROP"
	msg := sprintf("[firewall-baseline] %s has inbound_policy %q; it must be \"DROP\"", [rc.address, rc.change.after.inbound_policy])
}

# firewall_id is usually unknown at plan time (the firewall is created in the
# same run), which shows up in after_unknown. Only a value that is known to be
# empty is a violation.
deny contains msg if {
	some rc in changes("linode_instance")
	object.get(rc.change.after, "firewall_id", null) == null
	not object.get(rc.change, ["after_unknown", "firewall_id"], false)
	msg := sprintf("[firewall-baseline] %s has no firewall_id; instances must be created behind a Cloud Firewall", [rc.address])
}

# --- 4. No public SSH: TCP 22 must never be open to the whole internet ------

open_cidrs := {"0.0.0.0/0", "::/0"}

deny contains msg if {
	some rc in changes("linode_firewall")
	some rule in object.get(rc.change.after, "inbound", [])
	rule.action == "ACCEPT"
	rule.protocol in {"TCP", "ALL"}
	opens_ssh(rule)
	some cidr in array.concat(cidrs(rule, "ipv4"), cidrs(rule, "ipv6"))
	cidr in open_cidrs
	msg := sprintf("[no-public-ssh] %s rule %q opens SSH to %s", [rc.address, rule.label, cidr])
}

# --- Helpers ------------------------------------------------------------------

# Resource changes that create or update something. Deletes and no-ops are
# ignored so policies never block cleaning up non-compliant resources.
changes(resource_type) := [rc |
	some rc in input.plan.resource_changes
	rc.type == resource_type
	some action in rc.change.actions
	action in {"create", "update"}
]

# The plan JSON uses null (not []) for an unset CIDR list.
cidrs(rule, key) := [c | some c in object.get(rule, key, [])]

# No ports at all means "all ports".
opens_ssh(rule) if {
	object.get(rule, "ports", null) in {null, ""}
}

opens_ssh(rule) if {
	port_in_range(rule.ports, 22)
}

# True when `port` is covered by a Linode ports string like "22", "80,443" or "20-30".
port_in_range(ports, port) if {
	some part in split(ports, ",")
	trim_space(part) == sprintf("%d", [port])
}

port_in_range(ports, port) if {
	some part in split(ports, ",")
	bounds := split(trim_space(part), "-")
	count(bounds) == 2
	to_number(bounds[0]) <= port
	port <= to_number(bounds[1])
}
