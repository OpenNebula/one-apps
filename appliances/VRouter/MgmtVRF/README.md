# Management VRF for the VRouter appliance

## What it does

OpenNebula marks one NIC of a Virtual Router as the management NIC (`ETH<n>_VROUTER_MANAGEMENT=YES` in the VM context). one-context adds the default route of every NIC with `ip route add`, so the gateway of the first NIC wins and the default route of the management NIC collides with the one of the NIC that carries the traffic.

This module moves the management NIC into its own VRF, so its default route lives in a separate routing table and the main table stays free for the routed NICs. It is **on by default**: a router that does not set `ONEAPP_VNF_MGMT_VRF_ENABLED` gets the VRF at every boot.

Without a NIC marked as management the module does nothing.

## Marking the management NIC

Set `VROUTER_MANAGEMENT = "YES"` on the NIC of the Virtual Router template that should be the management NIC:

```
NIC = [ NETWORK = "management", VROUTER_MANAGEMENT = "YES" ]
```

OpenNebula passes it to the VM context as `ETH<n>_VROUTER_MANAGEMENT=YES`, where `<n>` is the index of the NIC. The module reads that variable, so `eth<n>` is the NIC that moves into the VRF. More than one NIC can be marked; they all move into the same VRF. A NIC that is not marked (or marked `NO`) stays in the main routing table.

## Attributes

| Name | Default | Meaning |
|---|---|---|
| `ONEAPP_VNF_MGMT_VRF_ENABLED` | `YES` | `NO` keeps the management NIC in the main routing table. A router that was booted with the VRF and is re-contexted with `NO` loses the VRF (the service is stopped, which removes it). |

The VRF is called `mgmt` and uses routing table `1000`. The policy rule for OneGate (see below) has the preference `100`. These values are fixed.

## What is configured

The `one-mgmt-vrf` OpenRC service runs after `sysctl` and `net`. On start it does the following, in this order:

1. Writes `/etc/sysctl.d/97-MgmtVRF.conf` with `net.ipv4.tcp_l3mdev_accept = 1` and `net.ipv4.udp_l3mdev_accept = 1`, so that listeners of the default VRF (sshd, for example) accept connections that arrive on the management NIC. The file is loaded with `sysctl --system` after the steps below.
2. Creates the VRF device `mgmt` (table 1000) if it does not exist, sets it up and moves every management NIC into it.
3. Puts the IPv6 configuration of the NIC back. Moving a NIC into a VRF flushes its IPv6 addresses and routes, so the static ones are restored the way one-context applies them: `ETH<n>_IP6` (or `ETH<n>_IPV6`) with `ETH<n>_IP6_PREFIX_LENGTH` (default 64), and `ETH<n>_IP6_ULA` as a `/64`.
4. Adds the default routes of the management NIC to table 1000: `ETH<n>_GATEWAY` for IPv4, and `ETH<n>_IP6_GATEWAY` (or `ETH<n>_GATEWAY6`) for IPv6 with `onlink`.
5. Adds the static routes of the management NIC to table 1000: the entries of `ETH<n>_ROUTES` (`<destination> via <gateway>`, separated by commas). Moving the NIC into the VRF drops them from the main table.
6. Adds the default routes of the NICs that are not management to the main table: `ETH<n>_GATEWAY` with `ETH<n>_METRIC` for IPv4, and `ETH<n>_IP6_GATEWAY` (or `ETH<n>_GATEWAY6`) for IPv6. one-context would have done this itself if the gateway of the management NIC had not come first. A NIC that already has a default route in the main table (for example one that one-context installed with a metric) keeps it, and nothing is added.
7. Adds a policy rule `pref 100 to <OneGate address> lookup 1000`. The appliance talks to OneGate from the default VRF, which cannot reach hosts behind the management NIC once it is enslaved; the rule sends that traffic to the VRF table, and the lookup falls through to the main table if the VRF has no route for it. A rule of an earlier run is deleted first, so repeated runs do not pile up rules.

On stop the service deletes the VRF device, which releases its NICs, deletes the policy rule and removes `/etc/sysctl.d/97-MgmtVRF.conf`. The routes of the VRF table are gone with the device, and one-context does not run again, so the service puts the IPv6 addresses, the default routes (`ETH<n>_GATEWAY` with `ETH<n>_METRIC`, and the IPv6 gateway) and the `ETH<n>_ROUTES` of the management NIC back into the main table, and the default routes of the other NICs where they are missing. A NIC that already has a default route in the main table keeps it.

With `ONEAPP_VNF_MGMT_VRF_ENABLED=NO` the service is stopped and disabled at every boot and re-contexting, also when someone enabled it by hand.

## Validation

Values end up in shell commands, so only plain notations are accepted. A rejected value is logged as an error that names the attribute (at most 40 characters of the value are logged) and the route or address it belongs to is skipped; the rest is configured.

| Value | Accepted |
|---|---|
| IPv4 gateway | dotted quad, each octet 0..255 |
| `ETH<n>_METRIC` | 1 to 9 digits |
| `ETH<n>_ROUTES` | comma-separated `<destination> via <gateway>` entries; the destination is a dotted quad with an optional prefix length 0..32, the gateway a dotted quad. Other entries are logged and skipped |
| IPv6 address, ULA, gateway | plain IPv6 notation (no prefix length, zone id or embedded IPv4 part); a link-local gateway is accepted |
| `ETH<n>_IP6_PREFIX_LENGTH` | 1..128 |
| OneGate address | taken from `ONEGATE_ENDPOINT`, only if the host is an IPv4 or IPv6 literal; a host name gets no rule |

## Constraints

- A service of the default VRF that opens connections to hosts behind the management NIC needs a route to them. Only OneGate gets one from this module.

## Tests

`tests.rb` (RSpec) checks the generated commands and their order for IPv4, IPv6, OneGate, the gateways of the other NICs, several management NICs, the disabled case and the cleanup.
