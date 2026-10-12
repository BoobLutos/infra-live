# Unit tests for the OPA policy set. Run with:
#   opa test policies/ policy-tests/ -v
#
# Kept outside policies/ so HCP Terraform only loads the policies themselves.
# The fixtures mirror the shape of `terraform show -json` plan output.
package terraform.policies_test

import data.terraform.policies.allowed_instance_types
import data.terraform.policies.allowed_regions
import data.terraform.policies.firewall_baseline
import data.terraform.policies.no_public_ssh
import data.terraform.policies.required_tags
import rego.v1

good_tags := ["app:pilot", "env:dev", "managed-by:terraform"]

good_firewall := {
	"address": "module.web.linode_firewall.this",
	"type": "linode_firewall",
	"change": {
		"actions": ["create"],
		"after": {
			"inbound_policy": "DROP",
			"outbound_policy": "ACCEPT",
			"tags": good_tags,
			"inbound": [
				{"label": "allow-http", "action": "ACCEPT", "protocol": "TCP", "ports": "80,443", "ipv4": ["0.0.0.0/0"], "ipv6": ["::/0"]},
				{"label": "allow-ssh-admin", "action": "ACCEPT", "protocol": "TCP", "ports": "22", "ipv4": ["203.0.113.10/32"], "ipv6": null},
			],
		},
		"after_unknown": {},
	},
}

good_instance := {
	"address": "module.web.linode_instance.this",
	"type": "linode_instance",
	"change": {
		"actions": ["create"],
		"after": {"region": "se-sto", "type": "g6-nanode-1", "tags": good_tags, "firewall_id": null},
		"after_unknown": {"firewall_id": true},
	},
}

good_vpc := {
	"address": "module.net.linode_vpc.this",
	"type": "linode_vpc",
	"change": {"actions": ["create"], "after": {"region": "se-sto"}, "after_unknown": {}},
}

plan(changes) := {"plan": {"resource_changes": changes}}

good_plan := plan([good_firewall, good_instance, good_vpc])

# Helpers to build bad variants of the good resources.
with_after(rc, patch) := object.union(rc, {"change": object.union(rc.change, {"after": object.union(rc.change.after, patch)})})

# Replaces after_unknown outright (object.union would merge the old keys back in).
with_after_unknown(rc, value) := object.union(
	object.remove(rc, ["change"]),
	{"change": object.union(object.remove(rc.change, ["after_unknown"]), {"after_unknown": value})},
)

with_actions(rc, actions) := object.union(rc, {"change": object.union(rc.change, {"actions": actions})})

# --- compliant plan passes everything ---------------------------------------

test_good_plan_passes_all_policies if {
	count(allowed_regions.deny) == 0 with input as good_plan
	count(allowed_instance_types.deny) == 0 with input as good_plan
	count(required_tags.deny) == 0 with input as good_plan
	count(firewall_baseline.deny) == 0 with input as good_plan
	count(no_public_ssh.deny) == 0 with input as good_plan
}

# --- allowed_regions ----------------------------------------------------------

test_region_outside_eu_denied if {
	bad := plan([with_after(good_instance, {"region": "us-east"})])
	count(allowed_regions.deny) == 1 with input as bad
}

test_vpc_region_checked if {
	bad := plan([with_after(good_vpc, {"region": "ap-south"})])
	count(allowed_regions.deny) == 1 with input as bad
}

test_deletes_are_never_blocked if {
	bad := plan([with_actions(with_after(good_instance, {"region": "us-east"}), ["delete"])])
	count(allowed_regions.deny) == 0 with input as bad
}

# --- allowed_instance_types ---------------------------------------------------

test_large_plan_denied if {
	bad := plan([with_after(good_instance, {"type": "g6-dedicated-8"})])
	count(allowed_instance_types.deny) == 1 with input as bad
}

# --- required_tags ------------------------------------------------------------

test_missing_tags_denied if {
	bad := plan([with_after(good_instance, {"tags": ["app:pilot"]})])
	count(required_tags.deny) == 2 with input as bad
}

test_null_tags_denied if {
	bad := plan([with_after(good_firewall, {"tags": null})])
	count(required_tags.deny) == 2 with input as bad
}

# --- firewall_baseline --------------------------------------------------------

test_accept_inbound_policy_denied if {
	bad := plan([with_after(good_firewall, {"inbound_policy": "ACCEPT"})])
	count(firewall_baseline.deny) == 1 with input as bad
}

test_instance_without_firewall_denied if {
	bad := plan([with_after_unknown(good_instance, {})])
	count(firewall_baseline.deny) == 1 with input as bad
}

test_instance_with_known_firewall_allowed if {
	ok := plan([with_after_unknown(with_after(good_instance, {"firewall_id": 2001}), {})])
	count(firewall_baseline.deny) == 0 with input as ok
}

# --- no_public_ssh ------------------------------------------------------------

ssh_rule(ports, ipv4, ipv6) := {"label": "ssh", "action": "ACCEPT", "protocol": "TCP", "ports": ports, "ipv4": ipv4, "ipv6": ipv6}

firewall_with_rule(rule) := with_after(good_firewall, {"inbound": [rule]})

test_ssh_open_to_world_denied if {
	bad := plan([firewall_with_rule(ssh_rule("22", ["0.0.0.0/0"], null))])
	count(no_public_ssh.deny) == 1 with input as bad
}

test_ssh_in_port_range_denied if {
	bad := plan([firewall_with_rule(ssh_rule("20-25,80", ["0.0.0.0/0"], null))])
	count(no_public_ssh.deny) == 1 with input as bad
}

test_ssh_open_over_ipv6_denied if {
	bad := plan([firewall_with_rule(ssh_rule("22", null, ["::/0"]))])
	count(no_public_ssh.deny) == 1 with input as bad
}

test_all_ports_open_denied if {
	bad := plan([firewall_with_rule(ssh_rule(null, ["0.0.0.0/0"], null))])
	count(no_public_ssh.deny) == 1 with input as bad
}

test_drop_rule_allowed if {
	rule := object.union(ssh_rule("22", ["0.0.0.0/0"], null), {"action": "DROP"})
	ok := plan([firewall_with_rule(rule)])
	count(no_public_ssh.deny) == 0 with input as ok
}

test_http_only_allowed if {
	ok := plan([firewall_with_rule(ssh_rule("80,443,8022", ["0.0.0.0/0"], ["::/0"]))])
	count(no_public_ssh.deny) == 0 with input as ok
}
