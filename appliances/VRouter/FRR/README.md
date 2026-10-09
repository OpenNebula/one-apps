# FRR (BGP, OSPF) module for the VRouter appliance

## What it does

This module runs FRR's `bgpd` (and `bfdd`; `ospfd` is enabled with the module and runs when its configuration has OSPF) inside the OpenNebula VRouter appliance and generates `/etc/frr/frr.conf` from `ONEAPP_VNF_BGP_*`, `ONEAPP_VNF_OSPF_*` and `ONEAPP_VNF_STATIC_ROUTES` attributes. The attributes are read from the VM context at boot and, while the VM runs, from the VM user template (through OneGate), so BGP can be changed without a reboot. It can also install static routes from `ONEAPP_VNF_STATIC_ROUTES` (see "Static routes"), with or without BGP. BGP neighbors, prefixes and static routes can be IPv4 or IPv6 (see "IPv6").

## Enabling

```
ONEAPP_VNF_BGP_ENABLED = "YES"
ONEAPP_VNF_ROUTER4_ENABLED = "YES"
```

`ONEAPP_VNF_ROUTER4_ENABLED` (stock forwarding) defaults to `NO`, unless the VM was created from an OpenNebula Virtual Router (`VROUTER_ID` is set), in which case it defaults to `YES`. `ONEAPP_VNF_BGP_ENABLED` defaults to `NO` and is read at boot only. FRR also runs, without BGP, when `ONEAPP_VNF_STATIC_ROUTES` is set in the context (see "Static routes").

## Attributes

All BGP attributes start with `ONEAPP_VNF_BGP_` (the static routes attribute is described in the next section). Blank values are treated as unset. Any other `ONEAPP_VNF_BGP_*` name (including a typo, or a zero-padded index such as `NEIGHBOR01_ADDRESS`) is an error, and the whole configuration is rejected.

Global:

| Name (after prefix) | Default | Meaning | Example |
|---|---|---|---|
| `ENABLED` | `NO` | Turns the module on. Boot only. | `YES` |
| `ASN` | none, required | Local AS number, 1..4294967295. Boot only. | `65010` |
| `ROUTER_ID` | IPv4 of the lowest-numbered `ETH<n>_IP` that is not a Virtual Router management NIC | BGP router id (IPv4). Boot only. Required if no such address exists. | `10.0.0.2` |
| `NETWORKS` | empty | Comma-separated prefixes to announce (`network`), no `ge`/`le`. | `192.0.2.0/24, 10.9.0.0/16` |
| `REDISTRIBUTE` | empty | Space or comma separated, any of `connected`, `static`, `kernel`. | `connected static` |
| `POLL_INTERVAL` | `30` | Seconds between runtime polls, 5..3600. | `60` |
| `BACKUP_PREPEND` | `3` | Extra AS-path prepends on the HA BACKUP node, 0..10. | `3` |
| `BACKUP_MED` | `200` | added to the MED of the exported routes on the HA BACKUP node (to the neighbor's `MED`, or to 0 when it has none), 0..4294967295. | `200` |

Per neighbor, `NEIGHBOR<N>_<KEY>`. `<N>` is a non-negative integer without leading zeros (`0`, `1`, `2`, ...; gaps are fine). `ADDRESS` and `ASN` are required for every `<N>` that is used; the same address twice is an error.

| Key | Default | Meaning | Example |
|---|---|---|---|
| `ADDRESS` | required | Neighbor IPv4 or IPv6 address. Its family decides the family of the session (see "IPv6"). | `10.0.0.1` |
| `ASN` | required | Remote AS, 1..4294967295. | `65001` |
| `DESCRIPTION` | none | Up to 64 characters of letters, digits, space, `.`, `-`, `_`. | `upstream-1` |
| `PASSWORD` | none | MD5 password, 1..80 characters, no whitespace, quotes or backslash. | `s3cret` |
| `BFD` | `NO` | `YES`/`NO` (also `1`/`0`). | `YES` |
| `BFD_TIMERS` | `3 300 300` | Three integers (multiplier 2..255, rx and tx 10..60000 ms); used only when `BFD` is on. The default renders as plain `neighbor X bfd`, as FRR prints it; other timers are rendered as a `bfd` profile (`BGP-N<index>`) because FRR never prints them on the neighbor line, and a candidate that differs from the printed config would reset BFD and BGP on every apply. | `3 300 300` |
| `TIMERS` | FRR default | Two integers: keepalive and hold time in seconds, each 0..65535; FRR refuses a hold time of 1 or 2. | `10 30` |
| `UPDATE_SOURCE` | none | An address of the neighbor's family or an interface name like `eth1`. | `eth1` |
| `MAX_PREFIX` | none | Maximum accepted prefixes, 1..4294967295. Applies to the neighbor's own address family block. | `1000` |
| `LOCAL_PREF` | none | Local preference set on routes imported from this neighbor, 0..4294967295. | `200` |
| `MED` | none | MED set on routes exported to this neighbor (MASTER), 0..4294967295. | `50` |
| `PREPEND` | `0` | Times the local ASN is prepended on export, 0..10. | `1` |
| `IMPORT_PREFIXES` | empty | Comma-separated prefixes, each optionally with `ge N` / `le N`. | `0.0.0.0/0, 198.51.100.0/24 le 28` |
| `EXPORT_PREFIXES` | empty | Same format, for routes sent to this neighbor. | `192.0.2.0/24` |

`NETWORKS` prefixes are announced only if the exact prefix exists in the routing table (FRR's `bgp network import-check`, on by default), for example as a connected or static route, or use `REDISTRIBUTE` instead.

Prefixes must be valid IPv4 or IPv6 with no host bits set (see "IPv6" for how the families are mixed). Filter semantics: an empty list accepts everything; a non-empty list permits only the listed prefixes and everything else is denied. A prefix without `ge`/`le` matches that exact prefix only.

### Example

```
ONEAPP_VNF_BGP_ENABLED = "YES"
ONEAPP_VNF_ROUTER4_ENABLED = "YES"
ONEAPP_VNF_BGP_ASN = "65010"
ONEAPP_VNF_BGP_ROUTER_ID = "10.0.0.2"
ONEAPP_VNF_BGP_NETWORKS = "192.0.2.0/24"
ONEAPP_VNF_BGP_NEIGHBOR1_ADDRESS = "10.0.0.1"
ONEAPP_VNF_BGP_NEIGHBOR1_ASN = "65001"
ONEAPP_VNF_BGP_NEIGHBOR1_DESCRIPTION = "upstream-1"
ONEAPP_VNF_BGP_NEIGHBOR1_PASSWORD = "s3cret"
ONEAPP_VNF_BGP_NEIGHBOR1_BFD = "YES"
ONEAPP_VNF_BGP_NEIGHBOR1_MAX_PREFIX = "1000"
ONEAPP_VNF_BGP_NEIGHBOR1_LOCAL_PREF = "200"
ONEAPP_VNF_BGP_NEIGHBOR1_PREPEND = "1"
ONEAPP_VNF_BGP_NEIGHBOR1_IMPORT_PREFIXES = "0.0.0.0/0, 198.51.100.0/24 le 28"
ONEAPP_VNF_BGP_NEIGHBOR1_EXPORT_PREFIXES = "192.0.2.0/24"
```

renders (hostname `vr1`, HA state MASTER; produced by the renderer itself):

```
frr defaults traditional
hostname vr1
log syslog informational
service integrated-vtysh-config
ip prefix-list BGP-N1-IN seq 10 permit 0.0.0.0/0
ip prefix-list BGP-N1-IN seq 20 permit 198.51.100.0/24 le 28
route-map BGP-N1-IN permit 10
 match ip address prefix-list BGP-N1-IN
 set local-preference 200
exit
ip prefix-list BGP-N1-OUT seq 10 permit 192.0.2.0/24
route-map BGP-N1-OUT permit 10
 match ip address prefix-list BGP-N1-OUT
 set as-path prepend 65010
exit
router bgp 65010
 bgp router-id 10.0.0.2
 no bgp default ipv4-unicast
 neighbor 10.0.0.1 remote-as 65001
 neighbor 10.0.0.1 description upstream-1
 neighbor 10.0.0.1 password s3cret
 neighbor 10.0.0.1 bfd
 address-family ipv4 unicast
  network 192.0.2.0/24
  neighbor 10.0.0.1 activate
  neighbor 10.0.0.1 route-map BGP-N1-IN in
  neighbor 10.0.0.1 route-map BGP-N1-OUT out
  neighbor 10.0.0.1 maximum-prefix 1000
 exit-address-family
exit
```

On the HA BACKUP node the same input renders `set metric 200` and `set as-path prepend 65010 65010 65010 65010` in `BGP-N1-OUT` (1 neighbor prepend + `BACKUP_PREPEND` 3).

## Static routes

`ONEAPP_VNF_STATIC_ROUTES` adds static routes to FRR. It is a global attribute, not a BGP one, and it works with or without BGP. The format is the one OpenNebula uses for `ETHx_ROUTES` and the network `ROUTES`: a comma-separated list of `<prefix> via <gateway>`, IPv4 or IPv6 (see "IPv6").

```
ONEAPP_VNF_STATIC_ROUTES = "1.1.1.1/32 via 172.16.100.1, 9.9.9.9/32 via 172.16.100.1"
```

Each entry is rendered as a top-level `ip route <prefix> <gateway>` (IPv4) or `ipv6 route <prefix> <gateway>` (IPv6) line of `frr.conf`, the IPv4 lines first, sorted the way FRR prints them (verified with FRR 10.2.1: `show running-config` prints exactly these lines, so re-applying the same attributes plans no change). The routes are the same on the HA master and backup.

- **Live changes.** Like the BGP attributes, the attribute is read from the context (baseline) and from the VM user template (override, picked up within `POLL_INTERVAL` seconds). Only the added or removed routes change; the BGP sessions are not reset. A blank override or a deleted line falls back to the context value.
- **`NONE`.** Because a blank override falls back to the context value, the keyword `NONE` (any case) means an empty list. Setting `ONEAPP_VNF_STATIC_ROUTES="NONE"` in the user template removes all routes, including those from the context; deleting the line brings the context routes back.
- **Without BGP.** If `ONEAPP_VNF_BGP_ENABLED` is not `YES` but the context has `ONEAPP_VNF_STATIC_ROUTES`, FRR starts with only the static routes: no `router bgp` block, no neighbors, no boot pin, and the other `ONEAPP_VNF_BGP_*` attributes are not validated. The poller still runs when OneGate is available, so the routes can be changed live. When BGP is disabled and the attribute is not set, nothing changes: FRR and the poller are stopped and disabled. To start a router without BGP and without routes and add routes later through the user template, set `ONEAPP_VNF_STATIC_ROUTES="NONE"` in the context (`NONE` counts as set for this purpose, so FRR runs with an empty config). `ONEAPP_VNF_BGP_ENABLED` stays boot-only: a value in the user template is ignored.
- **Validation.** Every entry must be `<prefix>/<length> via <gateway>` with a valid prefix without host bits and a valid global gateway of the same family as the prefix. Duplicate prefixes, an empty entry (a stray comma) and unknown syntax are errors; the error names `ONEAPP_VNF_STATIC_ROUTES`, and the whole configuration is rejected like any other invalid attribute (the running config stays as it is, `FRR_APPLY` says `rejected`). `dev`, `blackhole`, `reject`, metrics, `distance`, `tag` and similar options are refused with "not supported yet". A static default route is allowed: `0.0.0.0/0 via <gateway>` is an explicit opt-in.
- **Announcing the routes.** Static routes are not announced by default. Add `static` to `ONEAPP_VNF_BGP_REDISTRIBUTE` (or list the prefix in `ONEAPP_VNF_BGP_NETWORKS`). A route whose gateway is the BGP peer itself was not announced to that peer; use a gateway other than the peer you want to announce to.
- **Routes that `ETHx_ROUTES` already installed.** One-context installs the network's routes as plain kernel routes. Verified on real FRR: if the same prefix exists as a kernel route and as a static route, FRR lists both, the kernel route (`distance 0`) is `best` and installed, and the static route (`distance 1`) is not installed. FRR keeps the `ip route` line in its configuration, and the kernel table keeps only the kernel route. So a static route for a prefix that the network already provides has no effect; do not list those prefixes. Not tested: what happens when the kernel route disappears later.

`FRR_APPLY` reports the result of a route change like any other apply. The messages stay OneGate-safe: `=` `,` `[` `]` are replaced before they are stored.

## Where to set the attributes

The `KEY = "value"` lines above are shown without their container. There are two places.

At instantiate time (the baseline), inside the `CONTEXT` section of the VM or Virtual Router template, as comma-separated `KEY="value"` entries:

```
CONTEXT = [
  TOKEN = "YES",
  ONEAPP_VNF_ROUTER4_ENABLED = "YES",
  ONEAPP_VNF_BGP_ENABLED = "YES",
  ONEAPP_VNF_BGP_ASN = "65010",
  ONEAPP_VNF_BGP_ROUTER_ID = "10.0.0.2",
  ONEAPP_VNF_BGP_NEIGHBOR1_ADDRESS = "10.0.0.1",
  ONEAPP_VNF_BGP_NEIGHBOR1_ASN = "65001" ]
```

At runtime (overrides, no restart), as plain top-level attributes of the VM's user template, with the same key names, one per line (no `CONTEXT = [ ]` wrapper). `onevm update <id>` opens the user template in your editor (see the OpenNebula "User-defined Data" documentation); for example:

```
ONEAPP_VNF_BGP_NEIGHBOR2_ADDRESS="10.0.1.1"
ONEAPP_VNF_BGP_NEIGHBOR2_ASN="65002"
```

A non-empty value overrides the context value; an empty value, or a deleted line, falls back to the context value. Changes are picked up within `POLL_INTERVAL` seconds. `ONEAPP_VNF_BGP_ASN` and `ONEAPP_VNF_BGP_ROUTER_ID` are taken from the context only: in the user template they are ignored, at runtime and at the next boot. Editing the user template from Sunstone is also possible, but the exact UI path is not documented here (unverified).

`BGP_STATE` and `FRR_APPLY` show up in that same user template. The poller writes them; do not edit them by hand.

## Boot behavior

At boot, `configure` writes `/etc/frr/frr.conf` and (re)starts FRR. The first usable source wins:

1. The context plus the last remembered runtime overrides (`/var/lib/one-frr/overrides.json`), except `ASN` and `ROUTER_ID`, which always come from the context.
2. If those attributes are invalid (for example a rejected runtime override that is still remembered): `/var/lib/one-frr/last-good.conf`, the last config that FRR accepted (written by `configure` once FRR started with the boot config, and by every successful apply), if it exists and is not empty. The log names the file used.
3. Otherwise a minimal `frr.conf` without BGP and without static routes. BGP stays down until the attributes are fixed (at runtime if OneGate is available, otherwise at the next boot).

When the attributes are invalid, the validation errors are logged and the boot pin is cleared. `configure` never fails the appliance (FRR is configured before Keepalived, Failover and Router4, and an error would stop their configuration too):

- A missing, unreadable or non-object `overrides.json` is ignored (with a warning) and the context is used.
- If `rc-update add frr` fails, the error is logged and FRR is restarted anyway.
- Any other unexpected error while building `frr.conf` (hostname lookup, HA state, state files) is logged with its class and message, and FRR starts with the minimal config.
- The hostname must be 1..64 letters, digits, `.`, `-` or `_` (what FRR accepts). Any other hostname gives the minimal config without a `hostname` line, and runtime applies fail with `could not render the config` in `FRR_APPLY`.
- If FRR refuses to start with the config, it writes the minimal config and retries the restart once.
- If `ONEAPP_VNF_BGP_ENABLED` is not `YES` and `ONEAPP_VNF_STATIC_ROUTES` is not set, FRR and the poller are stopped and disabled. With static routes and no BGP, FRR starts with only the routes; invalid routes follow the same fallback as invalid BGP attributes (last-good, else a config without routes).

## Runtime changes

Put the same attribute names in the VM user template (`onevm update <id>`; see "Where to set the attributes"). The poller (an OpenRC service, `one-frr-poller`) reads the user template every `POLL_INTERVAL` seconds (default 30), merges it over the context (template wins), and applies the result if it changed. An empty value in the template counts as unset, so the context value is used. Nothing is applied if the merged attributes and HA state are unchanged.

An apply renders the config, checks it with `frr-reload.py --test`, loads it with `frr-reload.py --reload`, keeps it as last-good, then runs `clear bgp ipv4 unicast * soft` and `clear bgp ipv6 unicast * soft`. If the check fails the apply is `rejected` and the running config is untouched. If the reload fails, the last-good config is reloaded and the apply is `failed`: it is retried after 1, 3, 7, 15 and then 19 skipped polls (10 minutes at the default interval), so a config that FRR cannot load does not flap the sessions every poll. A `rejected` apply whose `frr-reload.py --test` failed is retried three times the same way (the test may fail while FRR is still starting); attributes that fail validation are not retried until they change. A change of the attributes or of the HA state is always applied at once. After a successful apply the config is also written to `/etc/frr/frr.conf`, so a restart of a daemon or of FRR keeps the live changes (if that write fails, the apply stays `applied` and `FRR_APPLY` says `could not update frr.conf`).

Every `frr-reload.py` and `vtysh` run is killed (with its process group) after 60 s and counts as failed. Applies are serialized by `/run/one-frr/apply.lock`; an apply that cannot get the lock within 60 s is `failed` (`could not acquire the apply lock within 60 s`) instead of waiting forever.

What it affects:
- Changing a neighbor's `ASN`, `PASSWORD` or `UPDATE_SOURCE` resets that neighbor's session (FRR behavior).
- `ASN` and `ROUTER_ID` are boot-only: `configure` pins them from the boot config to `/var/lib/one-frr/boot.json` (the poller also writes the pin after its first successful apply if none exists). The same holds for `ONEAPP_VNF_BGP_ROUTER_ID`, `ONEAPP_VNF_OSPF_ROUTER_ID` and `ONEAPP_VNF_FRR_ROUTER_ID`. A value in the user template is dropped before the apply (the poller logs `ignoring boot-only <names> in the user template`, and `FRR_APPLY` ends with `ignored boot-only <names> in the user template (set it in the VM context)`; the value itself is never shown) and is not used at the next boot either. To change them, change the VM context (e.g. `onevm updateconf`), then re-context or reboot the VM. A new boot rewrites the pin, or clears it if the config is invalid.
- `ENABLED` is read only at boot.
- Static routes (`ONEAPP_VNF_STATIC_ROUTES`) are added and removed live without touching the BGP sessions. Without BGP the apply skips the BGP soft refresh.
- Changes to `POLL_INTERVAL` take effect after the next applied change. Until an apply succeeds the poller uses the `POLL_INTERVAL` of the context (an integer from 5 to 3600, otherwise 30), so a poller started while the user template is invalid still polls at the interval of the context. A rejected or failed apply keeps the interval in use.

## OneGate requirement

The poller and the status reporting need OneGate: `ONEGATE_ENDPOINT` set in the VM context, with a token (`TOKEN = "YES"`, `ONEGATE_ENABLED = "YES"`), reachable either through the OpenNebula transparent proxy (`http://169.254.16.9:5030`) or through a NIC on a OneGate network. The poller is only started at boot when `ONEGATE_ENDPOINT` is set. Without it there is no runtime polling and no status reporting, but the overrides remembered in `/var/lib/one-frr/overrides.json` are still used at boot and the HA hook still switches the MASTER/BACKUP profile.

When OneGate does not answer, the poller keeps using the last overrides it saw (persisted in `overrides.json`), logs one warning, skips publishing the status, and backs off: the time between polls doubles with every further failed poll (with the default interval: 30, 60, 120, ... s) up to 600 s, never below `POLL_INTERVAL`, and goes back to `POLL_INTERVAL` once OneGate answers. The stock OneGate client still logs each failed request. The stock client can also raise (`IOError`, "HTTP session not yet started", when the connection cannot be opened) instead of returning nothing; the poller counts that like no answer (same warning, with the error class only, and the same backoff) and keeps applying the last overrides.

## Status

`onevm show <id>` shows these attributes in the user template (`BGP_STATE` only when BGP is enabled, `OSPF_STATE` only when OSPF is enabled):

- `OSPF_STATE`: `<router-id>: <state> <interface>; ...` per OSPF neighbor (for example `10.0.0.2: Full/DR eth1`), or `no neighbors`.
- `BGP_STATE`: `<address>: <state> rcv <n> snt <n>; ...` per neighbor (for example `10.0.0.1: Established rcv 3 snt 1`), or `no neighbors`. There is no uptime, so the value only changes when something changes.
- `FRR_APPLY`: `<applied|rejected|failed> <time> <message>`, with an ISO 8601 UTC time. It reports the apply of the whole FRR configuration (BGP and static routes). The message is empty on a clean success. Passwords are replaced by `***`: the value after any `password` keyword in the `frr-reload.py` output, and every password of the new and of the last-good config wherever it appears (the poller log gets the same scrubbed message). Quotes, backslashes and newlines are replaced by spaces and the value is cut at 300 characters. OneGate rejects (HTTP 500) a quoted value that contains `=`, `,`, `[` or `]`, so the module replaces them with `:`, `;`, `(` and `)` in everything it writes back. A failed write is logged once per distinct error and retried after 60 s. A write counts as sent only when OneGate answers with an empty body: no answer at all (the stock client returns nothing when the request failed) or an exception is a failure too, retried after 60 s, and `publish` never raises because of OneGate. `none` is shown until the first apply.

They are updated when the text changes.

## High availability

The module needs the failover hooks (`/etc/one-appliance/ha-hooks.d/`, the change in OpenNebula/one-apps PR #405): the stock Failover of an image without them never runs `10-frr`, so both nodes would keep the MASTER profile and advertise the same attributes. FRR runs on both nodes and keeps its BGP sessions on the standby; it is not in Failover's service list. On a state change Failover runs the hooks in `/etc/one-appliance/ha-hooks.d/` with `up` (MASTER) or `down` (BACKUP), each bounded by a 30 s timeout (the hook's process group is killed). On `up` the hooks run last, after the stock services (`Router4`, `NAT4`, ...) were restarted, so forwarding never waits for them; on `down` they run first, before the services are stopped.

The FRR hook `10-frr` writes `master` or `backup` to `/run/one-frr/ha-state` and re-applies the config offline: from the context and the remembered overrides, with no OneGate request and no status publish. The poller picks up the new HA state on its next poll and publishes `BGP_STATE`/`FRR_APPLY`.

- MASTER: the attributes apply as configured.
- BACKUP: the export route-map of every neighbor raises the MED by `BACKUP_MED` (on top of the neighbor's own `MED`, so the backup is never better than the master) and prepends the local ASN `NEIGHBOR<N>_PREPEND + BACKUP_PREPEND` times. Local preference is not part of the profile (it is not sent over eBGP); `LOCAL_PREF` stays a static import setting.
- A single VM, with no peer, elects itself VRRP MASTER, and the stock services (`Router4`, `NAT4`, ...) start through Failover `up`.

Known limitation: the standby has forwarding stopped by the stock Failover. If the master's BGP session fails while VRRP stays healthy, traffic can still reach the backup (which advertises the routes too, de-preferred) and be dropped there. The follow-up is BFD plus a VRRP track on the BGP session.

## OSPF

OSPFv2 as an IGP between the vRouter nodes and the internal routers. Off by default; `ONEAPP_VNF_OSPF_ENABLED` and the router-id are read at boot only (context), everything else can be changed live from the VM user template, like BGP.

```
ONEAPP_VNF_OSPF_ENABLED          = "YES"
ONEAPP_VNF_OSPF_INTERFACE0_NAME  = "eth1"
ONEAPP_VNF_OSPF_INTERFACE0_AREA  = "0"
ONEAPP_VNF_OSPF_INTERFACE0_PASSWORD = "s3cretkey"
```

Global attributes:

| Attribute | Default | Meaning |
|---|---|---|
| `ONEAPP_VNF_OSPF_ENABLED` | `NO` | `YES`/`NO` (also `1`/`0`), boot-only |
| `ONEAPP_VNF_OSPF_ROUTER_ID` | see below | IPv4 router-id, boot-only |
| `ONEAPP_VNF_OSPF_DEFAULT_ORIGINATE` | `NO` | `NO`, `YES` (only while the router has a default route) or `ALWAYS` |
| `ONEAPP_VNF_OSPF_REDISTRIBUTE` | empty | `connected` and/or `static`, redistributed into OSPF (nothing else, and nothing out of OSPF) |
| `ONEAPP_VNF_OSPF_BACKUP_COST` | `100` | added to the cost of every OSPF interface and to the metric of the routes this node originates or redistributes while it is the VRRP backup, so peers prefer the master (0..65535; the interface cost sum is capped at 65535) |

Per interface, `ONEAPP_VNF_OSPF_INTERFACE<n>_…` with n = 0, 1, 2, …:

| Attribute | Default | Meaning |
|---|---|---|
| `NAME` | required | the interface, `eth<n>`; each name once |
| `AREA` | `0` | a number or a dotted quad (stored as the number) |
| `COST` | `10` | 1..65535 |
| `PASSIVE` | `NO` | advertise the network but form no adjacency |
| `NETWORK_TYPE` | `broadcast` | `broadcast` or `point-to-point` |
| `HELLO_INTERVAL` / `DEAD_INTERVAL` | `10` / `40` | seconds; the dead interval must be greater than the hello interval |
| `PASSWORD` | none | MD5 key (key id 1), at most 16 characters without whitespace, quotes or backslash; both neighbors need the same |
| `BFD` | `NO` | BFD with FRR's default timers |

A slot without `NAME` but with other keys is an error that names the slot. Unused slots stay empty.

**Router-id.** Most specific first: `ONEAPP_VNF_OSPF_ROUTER_ID` (OSPF) or `ONEAPP_VNF_BGP_ROUTER_ID` (BGP), then `ONEAPP_VNF_FRR_ROUTER_ID` (shared by both), then the IPv4 address of the first routed NIC. All are boot-only; OSPF pins its router-id in `boot.json` as `ospf_router_id`.

**What is sent to FRR.** `cost` is always sent. Values equal to FRR's defaults (`hello-interval 10`, `dead-interval 40`, `network broadcast`) are not: FRR does not print `hello-interval 10` back, so sending it would make `frr-reload` re-plan on every apply.

**High availability.** FRR runs on both nodes. The VRRP backup advertises `COST + BACKUP_COST` on every OSPF interface, the master the plain `COST`. A peer chooses between two routers that advertise the same *external* route (the default route from `DEFAULT_ORIGINATE`, the routes from `REDISTRIBUTE`) by the external metric, not by the interface costs, so the backup also sends an explicit metric: FRR's default plus `BACKUP_COST` (`default-information originate … metric 1+N`, `redistribute … metric 20+N`). The master sends no metric, so FRR's defaults (1 and 20) apply. Measured on FRR 10.2.1: with equal metrics a peer installs both routers as equal-cost next hops.

**Limits.** OSPFv2 only (no OSPFv3), one instance, no redistribution out of OSPF or between OSPF and BGP, no virtual links, stub areas or area ranges, BFD timers cannot be changed. The MD5 key is written to `frr.conf` (`0640`, group `frr`) like the BGP passwords and is scrubbed from messages.

## How the module is organised

The module configures *sections*: static routes (`ONEAPP_VNF_STATIC_ROUTES`), BGP (`ONEAPP_VNF_BGP_*`) and OSPF (`ONEAPP_VNF_OSPF_*`). Each section is a module under `sections/` that parses its own attributes, renders its own part of `frr.conf` (`templates/<section>.erb`), and says which daemons, boot-only values, secrets, soft-refresh commands and status key it has. The core (`attributes`, `config`, `renderer`, `applier`, `reloader`, `reporter`, `poller`, `main`) loops over `Sections::ALL` and knows no protocol. A new protocol is a new section module plus its partial, added to `Sections::ALL` and `Sections::RENDER_ORDER`; `bfdd` is enabled by the core because several protocols can use BFD.

OneGate keys: one `<SECTION>_STATE` key per configured section with a status (`BGP_STATE`, `OSPF_STATE`), and `FRR_APPLY` for the result of the last apply of the whole configuration.

## Paths

| Path | Purpose |
|---|---|
| `/etc/frr/frr.conf` | config FRR starts with |
| `/var/lib/one-frr/` | `overrides.json`, `boot.json` (pin), `candidate.conf`, `last-good.conf`; directory `0700`, files `0600` (they hold passwords) |
| `/run/one-frr/ha-state` | `master` or `backup` |
| `/run/one-frr/apply.lock` | serializes applies (poller and HA hook) |
| `/etc/one-appliance/ha-hooks.d/10-frr` | Failover hook |
| `/etc/init.d/one-frr-poller` | poller service (logs in `/var/log/one-appliance/one-frr-poller.log`) |

## Routers without a default route

By default the module treats the default route like any other route: with an empty filter, a received `0.0.0.0/0` is accepted and an existing one is announced. Nothing is special-cased. For routers that must not have a default route and should only keep a few specific routes towards the internet, there are two cases, depending on where the default comes from.

**A. The default arrives over BGP.** Set `ONEAPP_VNF_BGP_NEIGHBOR<N>_IMPORT_PREFIXES` to just the routes you want, for example `203.0.113.0/24, 198.51.100.0/24`. A non-empty list permits only the listed prefixes and denies everything else, so `0.0.0.0/0` is not accepted. This is the normal prefix-filter behavior and can be changed live through the user template.

**B. The default comes from the network gateway.** The gateway and static routes are attributes of the OpenNebula **virtual network** (or its address range), not of the VM context. A `ETHx_GATEWAY` or `ETHx_ROUTES` entry in the VM's `CONTEXT` is overwritten by the values OpenNebula generates from the network (observed on OpenNebula 7.4.1: the context kept the network's gateway and empty routes). So use a network without `GATEWAY` and with `ROUTES`:

```
NAME="no-default"
BRIDGE="minionebr"
VN_MAD="fw"
ROUTES="1.1.1.1/32 via 172.16.100.1, 9.9.9.9/32 via 172.16.100.1"
AR=[ TYPE="IP4", IP="172.16.100.200", SIZE="10" ]
```

(`ROUTES` format: `<destination> via <gateway>, <destination> via <gateway>`, see the OpenNebula virtual network template reference. Attach the router's NIC to this network instead of the one with the gateway.)

Observed on a router attached to such a network (verified on a real VM):

- no default route in `ip route`; the two specific routes are present with `via` the gateway;
- `ip route get 1.1.1.1` and `9.9.9.9` resolve via the gateway, `ip route get 8.8.8.8` answers `Network unreachable`;
- with `ONEAPP_VNF_BGP_REDISTRIBUTE="static,kernel"` the router announced exactly those two routes (and no default, since it has none). A BGP peer learned them, and a second peer behind it learned them through the first, because empty filters accept everything. The BGP next hop stays the gateway address, so the peers need a path to it (true on a shared subnet).

**B, live.** The same result without putting the routes on the network: attach the router to a network without a `GATEWAY` and set `ONEAPP_VNF_STATIC_ROUTES="1.1.1.1/32 via 172.16.100.1, 9.9.9.9/32 via 172.16.100.1"` (in the context, and later in the user template to change them live, `NONE` to remove them all). The router then has exactly those routes and no default route. The module installs them in FRR (`ip route` lines); they reach the kernel table, are announced with `REDISTRIBUTE=static` and can be added and removed live. Do not list a prefix that the network's `ROUTES` already provides (see "Routes that `ETHx_ROUTES` already installed"). This variant was not run on a real VM.

Notes:

- Routes from the network's `ROUTES` are installed when the VM is contextualized (reboot or re-contextualization); they cannot be changed live. To change routes live, use `ONEAPP_VNF_STATIC_ROUTES` (see "Static routes", and the live variant of case B below).
- Other levers, stock behavior and not re-tested here: a NIC that only carries the floating IP gets its default route from keepalived and only on the VRRP master; `ONEAPP_VNF_ROUTER4_INTERFACES` limits which NICs forward (the parser accepts a list or exclusions like `!eth1`; checked at the parser level, not with traffic through a two-NIC router); do not enable NAT on a NIC that must not reach the internet.

## IPv6

IPv6 is supported for BGP neighbors, announced and filtered prefixes and static routes. The gaps are listed at the end of this section.

**IPv6 neighbors.** The family of `NEIGHBOR<N>_ADDRESS` decides the family of the session: an IPv6 address gives an IPv6 session, an IPv4 address an IPv4 session. A neighbor is single-stack, one neighbor is one family. Only global and ULA addresses are accepted; a link-local neighbor address (`fe80::/10`) is rejected with "not supported yet", and so are `::`, `::1` and multicast (`ff00::/8`) as neighbor address, update source or static route gateway. `UPDATE_SOURCE` takes an address of the same family as the neighbor or an interface name. Example, an IPv6 neighbor next to an IPv4 one:

```
ONEAPP_VNF_BGP_NEIGHBOR1_ADDRESS = "10.0.0.1"
ONEAPP_VNF_BGP_NEIGHBOR1_ASN = "65001"
ONEAPP_VNF_BGP_NEIGHBOR2_ADDRESS = "fd77::21"
ONEAPP_VNF_BGP_NEIGHBOR2_ASN = "65002"
ONEAPP_VNF_BGP_NEIGHBOR2_IMPORT_PREFIXES = "2001:db8::/32 le 48"
```

The renderer puts an IPv6 neighbor in `address-family ipv6 unicast`, with `ipv6 prefix-list` and `match ipv6 address` in its route maps. Measured with real FRR 10.2.1: IPv6 sessions reach Established next to the IPv4 session, and adding, removing or changing IPv6 neighbors, filters and static routes live does not drop the IPv4 session; applying the same attributes again plans no change. FRR does not print an empty `address-family ipv4 unicast` block, so for an IPv6-only configuration (no IPv4 neighbor, no IPv4 `NETWORKS` entry, no `REDISTRIBUTE`) the renderer omits it. IPv4-only configurations render as before: the rendered `frr.conf` of a set of IPv4-only configurations (every neighbor option, the backup profile, a BFD profile, static routes only, and no BGP) was compared before and after the IPv6 renderer changes and was identical (a one-off comparison, not a test in the suite). The router-id stays IPv4, also with IPv6 neighbors (see `ROUTER_ID`); it is required when the node has no IPv4 address on a routed NIC.

**Prefix lists.** `NETWORKS`, `IMPORT_PREFIXES` and `EXPORT_PREFIXES` take IPv4 and IPv6 prefixes in one list (`ge`/`le` lengths must fit the family). A neighbor uses only the entries of its own family:

| List of the neighbor | Effect for that neighbor | Example (IPv6 neighbor) |
|---|---|---|
| empty | accepts everything | `IMPORT_PREFIXES` unset |
| has entries of its own family | permits only those | `2001:db8::/32 le 48, 192.0.2.0/24` permits only `2001:db8::/32 le 48` |
| has entries only of the other family | permits nothing (the route map ends in a `deny`) | `192.0.2.0/24` permits no IPv6 route |

`MAX_PREFIX` applies to the neighbor's own address family. `NETWORKS` entries are announced in the family block they belong to, subject to the `network import-check` described above.

**Static routes.** `ONEAPP_VNF_STATIC_ROUTES = "2001:db8::/32 via fd77::1, 1.1.1.1/32 via 172.16.100.1"`. The gateway must be a global address of the same family as the prefix (a mixed entry and a link-local gateway are rejected). The routes are sorted IPv4 first, then by prefix length and address, and `NONE` means no routes, as for IPv4. IPv6 routes are added and removed live without touching the BGP sessions.

**IPv6 gaps.**

- No NAT66.
- No link-local peers: neighbor addresses and static route gateways must be global or ULA.
- No dual-stack sessions: one neighbor is one family, a second family needs a second neighbor.
- Applying a configuration through `frr-reload` turned `net.ipv6.conf.all.forwarding` on (measured), so with FRR active IPv6 may be forwarded after the first apply. There is no IPv6 filtering in the image.
- IPv4-mapped IPv6 addresses (`::ffff:a.b.c.d`) are rejected.
- The router-id must be an IPv4 address.

## Known limitations

- Routes that come from the network's `ROUTES` / `ETHx_ROUTES` are set at contextualization time, not live (use `ONEAPP_VNF_STATIC_ROUTES` for live routes).
- After the last BFD configuration is removed, FRR keeps an empty `bfd` section that `frr-reload.py` plans to delete (`no bfd`) on every later apply without ever removing it. It changes nothing on the running router, but such an apply is not an empty diff.
- IPv6 gaps: see the list at the end of "IPv6" (no NAT66, no IPv6 filtering, no link-local peers, no dual-stack sessions, the forwarding side effect, and more).
- No packet filtering in the image. Use OpenNebula security groups.
- No AS-path or community filters; filtering is by prefix only.
- Neighbor passwords are readable in the VM template (context and user template).
- The stock OneGate client does not verify TLS certificates.
- `/etc/frr/frr.conf` (`0640`, group `frr`) contains the neighbor passwords, as FRR needs them.

## OpenNebula template inputs

The module ships no template: the VRouter service template is part of the marketplace appliance, and needs one user input and one `CONTEXT` entry per attribute it should offer (`ONEAPP_VNF_BGP_*`, `ONEAPP_VNF_OSPF_*`, `ONEAPP_VNF_FRR_ROUTER_ID` and `ONEAPP_VNF_STATIC_ROUTES`; the tables above list names, defaults and formats). Notes for whoever writes them:

- The per-neighbor and per-interface inputs may carry defaults such as `NEIGHBOR1_BFD=NO` or `INTERFACE1_PASSIVE=NO`: a slot with only such values is ignored. Any other value without `NEIGHBOR<N>_ADDRESS`/`_ASN` (or `INTERFACE<N>_NAME`) makes the slot incomplete, and the whole BGP (or OSPF) configuration is rejected with `neighbor slot 1 is incomplete`.
- `ONEAPP_VNF_STATIC_ROUTES` is an optional text input; `NONE` means no routes.
- Address and prefix inputs accept IPv6 values (see "IPv6").
- Attributes that are not in the template (for example neighbors 2 and up) can still be set in the VM context or the user template.

## Running the tests

The unit specs run with the others from the repository root (`appliances/VRouter/tests.sh`, needs `rspec`), or alone from this directory with `rspec tests.rb`. Expected: `483 examples, 0 failures`.

`spec/golden_spec.rb` renders 28 attribute sets (BGP, static routes and OSPF) and compares them byte for byte with `spec/fixtures/golden/*.conf`, so a refactor cannot change what FRR is given. Regenerate the fixtures on purpose only: `GOLDEN_UPDATE=1 rspec spec/golden_spec.rb` in this directory.
