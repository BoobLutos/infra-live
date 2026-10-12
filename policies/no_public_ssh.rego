# SSH (TCP 22) must never be open to the whole internet.
package terraform.policies.no_public_ssh

import rego.v1

open_cidrs := {"0.0.0.0/0", "::/0"}

deny contains msg if {
	some rc in changes("linode_firewall")
	some rule in object.get(rc.change.after, "inbound", [])
	rule.action == "ACCEPT"
	rule.protocol in {"TCP", "ALL"}
	opens_ssh(rule)
	some cidr in array.concat(cidrs(rule, "ipv4"), cidrs(rule, "ipv6"))
	cidr in open_cidrs
	msg := sprintf("%s rule %q opens SSH to %s", [rc.address, rule.label, cidr])
}

# The plan JSON uses null (not []) for an unset CIDR list.
cidrs(rule, key) := [c | some c in object.get(rule, key, [])]

# No ports at all means "all ports".
opens_ssh(rule) if {
	object.get(rule, "ports", null) in {null, ""}
}

opens_ssh(rule) if {
	port_in_range(rule.ports, 22)
}

# Resource changes that create or update something. Deletes and no-ops are
# ignored so policies never block cleaning up non-compliant resources.
changes(resource_type) := [rc |
	some rc in input.plan.resource_changes
	rc.type == resource_type
	some action in rc.change.actions
	action in {"create", "update"}
]

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
