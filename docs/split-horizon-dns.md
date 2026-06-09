# Split-Horizon DNS

Split-horizon DNS lets one service name resolve differently based on where the
client is located:

```text
LAN client     -> app.example.com -> local reverse proxy
Roaming client -> app.example.com -> public ingress
```

The design goal is not merely a successful lookup. Local traffic should stay
local, roaming traffic should remain portable, and a DNS filtering layer should
not accidentally replace authoritative local behavior.

## Layer Responsibilities

| Layer | Responsibility |
| --- | --- |
| AdGuard Home | Filtering, client policy, and selection of upstream resolvers |
| Unbound | Local overrides, recursive resolution, and authoritative local answers |
| Directory DNS | Domain and service records required by the directory platform |
| Public DNS | Public ingress records for roaming clients |

Keep these responsibilities explicit. A broad rewrite in the filtering layer
is easy to add and difficult to reason about later.

## Recommended Pattern

1. Put local service overrides in the local resolver.
2. Scope custom upstream behavior to known LAN subnets or client groups.
3. Forward directory zones to directory DNS instead of reproducing them by
   hand.
4. Leave public service records valid for clients that are not on the LAN.
5. Use low-risk test names before changing an established service.

Example using documentation-only addresses:

```text
app.example.com. 60 IN A 192.0.2.20
```

The public DNS record might instead point at a public ingress provider. Replace
the documentation address with the local reverse proxy address in your own
resolver.

## Why Global Rewrites Fail

A global filtering-layer rewrite can cause several classes of failure:

- roaming or VPN clients receive an unreachable LAN address;
- a service unexpectedly bypasses its public authentication path;
- all clients inherit a workaround intended for one subnet;
- the filtering layer becomes an undocumented authoritative DNS server;
- recovery becomes harder because the effective answer depends on hidden
  client policy.

## Validation Matrix

Test from more than one location:

```sh
dig app.example.com
dig @resolver.example app.example.com
curl -I https://app.example.com
```

Record and compare:

| Client | Expected DNS path | Expected HTTP path |
| --- | --- | --- |
| LAN workstation | Local resolver | Local reverse proxy |
| Guest network | Public or restricted resolver | Public ingress or denial |
| Mobile network | Public DNS | Public ingress |
| Overlay client | Chosen policy, documented explicitly | Overlay or public ingress |

Also test failure behavior. If the local resolver is unavailable, clients
should fail predictably rather than silently switching into a path that bypasses
policy.

## Change Checklist

Before adding a service hostname:

1. Identify the public and local upstreams.
2. Decide which clients receive each answer.
3. Confirm TLS names match both paths.
4. Confirm the authentication callback uses the public service name.
5. Test LAN and roaming clients independently.
6. Remove temporary broad rewrites after the scoped rule is working.
