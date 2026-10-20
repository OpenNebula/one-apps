# Failover service for the VRouter appliance

## What it does

The `one-failover` OpenRC service follows the VRRP role of the router. Keepalived writes its state changes to a FIFO (`/run/keepalived/vrrp_notify_fifo.sock`), and the service reacts to the event of the VRRP sync group (`GROUP`) only. Events of single instances are ignored.

- **MASTER** (`up`): waits until Keepalived is ready, loads the VM context, then restarts the services that are enabled in the context and stops the others. The services are the ones in the `SERVICES` table of `execute.rb` (Router4, NAT4, LVS, HAProxy, SDNAT4, DNS, DHCP4, WireGuard, each controlled by its `ONEAPP_VNF_*_ENABLED` attribute).
- **BACKUP** (`down`): waits until Keepalived is on standby and stops all of those services.
- `FAULT`, `STOP` and `DELETED` change nothing. If the event loop fails, all services are stopped to avoid a conflict between the nodes.

The last role is kept in `/run/one-failover.state` (`{"state":"MASTER"}`, `BACKUP`, ...). It is written before the `up` or `down` step runs.

## Hooks

Other services can follow the VRRP role without a change to this module. Put an executable file into `/etc/one-appliance/ha-hooks.d/`. The service runs every executable file of that directory, in name order, with one argument:

| Argument | When | Order |
|---|---|---|
| `up` | the node became MASTER | after the stock services were restarted, so forwarding does not wait for a hook |
| `down` | the node became BACKUP | first, before the stock services are stopped |

Use a numeric prefix (`10-bgp`, `20-conntrack`) to fix the order. Files that are not executable, and directories, are skipped. A missing directory is not an error.

Rules for a hook:

- **Run again.** `down` runs for every BACKUP event, not only for a change of role (a node that boots as BACKUP, a repeated event, and after an error of the event loop). `up` runs only when the role changed to MASTER. A hook has to be safe to run twice in a row.
- **Environment.** `up` hooks see the VM context in their environment (the service loads it before it runs the hooks). `down` hooks do not: a hook that needs a context value reads it itself, for example from `/run/one-context/one_env`, without sourcing it in a shell.
- **Time.** A hook is killed after 30 seconds, together with its whole process group. Hooks run one after the other, so N hooks can delay the failover by up to N times 30 seconds. Keep them short and start long-running work in the background through the init system.
- **Failure.** A hook never breaks the failover. A non-zero exit, a timeout, a signal or an error to start the hook is logged as an error in `/var/log/one-appliance/one-failover.log` (with the tail of its output, at most 4096 bytes) and the next hook runs.
- **Output.** The output of a hook goes to a temporary file, not to a pipe, so a child that outlives the hook cannot block the failover. It is only logged when the hook fails.
- **Role.** A hook can read the current role from `/run/one-failover.state`; the argument is what to do now.

Example (`/etc/one-appliance/ha-hooks.d/50-example`, mode `0755`):

```sh
#!/bin/sh
case "$1" in
up)   logger -t ha-hook "became MASTER" ;;
down) logger -t ha-hook "became BACKUP" ;;
esac
```

## Tests

`tests.rb` (RSpec) covers the hooks (order, argument, non-executable files, a missing directory, failing, signal-killed, hanging and unstartable hooks, and a background child that outlives its hook), the position of the hooks relative to the stock steps in `up` and `down`, and the handling of the VRRP events (single instances are ignored, the group event is acted on).
