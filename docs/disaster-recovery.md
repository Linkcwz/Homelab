# Disaster Recovery

Disaster recovery is a dependency problem before it is a backup problem. A
perfect application backup is not useful if the network, storage, identity, or
name-resolution layers required to reach it are still unavailable.

## Recovery Tiers

| Tier | Services | Proof of recovery |
| --- | --- | --- |
| 0 | Hypervisor and break-glass access | Console or independent administrator login works |
| 1 | Routing, firewall, DHCP, and DNS | A client receives an address and resolves public and local names |
| 2 | Storage | Required datasets mount and pass read/write checks |
| 3 | Directory and web identity | Directory queries and interactive SSO succeed |
| 4 | TLS ingress | Certificates load and reverse-proxy health checks pass |
| 5 | Developer and application services | Application-specific checks pass |
| 6 | Observability | Monitoring sees the restored platform and alerts are actionable |
| 7 | User path | A real client completes the intended workflow |

The included recovery-plan validator turns this dependency order into an
executable check.

## A Real Migration, Not a Drill

Workloads were migrated off one Proxmox node (NA1) and onto another (Delta) while
the platform stayed usable throughout — the dependency-ordered recovery above,
run live.

Critical capabilities are also replicated off the primary cluster entirely, so
they survive losing the main hypervisor:

- **Identity / SSO** (Authentik) and the **overlay VPN** (NetBird) are
  replicated onto a Windows workstation (Hermes), so single sign-on and routed
  remote access do not die with the primary cluster.
- The same overlay and split-horizon DNS ride along on a **pocket-sized travel
  router**, so "the homelab" fits in a bag and access keeps working away from
  the rack (see [travel-router validation](travel-router.md)).
- **Nextcloud** (private-cloud file sync) is replicated onto Hermes as well,
  giving the file and sync capability a second home that does not depend on the
  primary storage node.

The point is not that everything runs in three places at once — it is that
identity, remote access, and private-cloud storage each have a tested fallback
that does not depend on a single box.

## Preserve Independent Access

Break-glass access must not depend on the identity provider hosted inside the
platform being recovered. Keep at least one tested local or hardware-console
path for the virtualization and network layers.

Likewise, preserve an off-platform copy of:

- recovery runbooks;
- infrastructure configuration exports;
- encryption recovery material;
- repository history;
- a current service inventory;
- restore validation commands.

The copy should be readable when the primary identity, DNS, storage, and Git
systems are unavailable.

## Recover by Capability

Restore a capability, prove it, then move upward:

1. Establish console and network control.
2. Restore DNS behavior required by the next layer.
3. Mount storage without changing application data unnecessarily.
4. Restore identity and verify both machine and interactive flows.
5. Restore ingress and certificates.
6. Start dependent applications in order.
7. Restore monitoring after the underlying targets exist.
8. Validate from an actual user endpoint.

Avoid starting every workload at once. Parallel startup hides dependency
failures and creates misleading secondary errors.

## Recovery Evidence

Each service entry should define checks at three levels:

- **local**: process, socket, or container health;
- **dependency**: DNS, storage, identity, or upstream connectivity;
- **user path**: the external action the service exists to support.

For a browser IDE, process health is not enough. Recovery evidence might include
successful SSO, workspace start, terminal connection, file persistence, and a
Git operation from the workspace.

## Temporary Recovery Regions

A surviving host can act as a temporary recovery region. Treat it as temporary:

- document which services moved and why;
- avoid creating new hidden dependencies on the temporary host;
- preserve original data until validation is complete;
- decide explicitly whether each workload returns, stays, or is rebuilt;
- update recovery plans after the incident.

Recovery work often reveals a better long-term topology. Capture that learning,
but do not redesign every layer while basic service is still unstable.
