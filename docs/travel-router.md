# Travel Router Validation

A travel router is most useful when it remains a router under partial failure.
Overlay networking, filtered DNS, and homelab routes are optional capabilities;
they must not break ordinary Wi-Fi or Ethernet WAN behavior.

## Priority Order

1. LAN DHCP and local administration.
2. Wi-Fi and Ethernet WAN acquisition.
3. Default route and NAT for LAN clients.
4. Access-point availability.
5. DNS for ordinary internet use.
6. Overlay reachability.
7. Private routes and split-horizon DNS.

This ordering prevents a failed overlay or private resolver from turning the
router into a device that only works when the homelab is healthy.

## OpenWrt Checks

The following commands are broadly useful on OpenWrt-derived systems:

```sh
ubus call system board
ifstatus wan
ifstatus wwan
ip -4 route show default
ip -4 addr show
logread -e netifd
fw4 check
nft list table inet fw4
```

Interface names vary by vendor. Use `ubus call network.interface dump` and
`iw dev` to discover the current shape rather than hard-coding assumptions.

## Test Matrix

| Scenario | Expected result |
| --- | --- |
| Wi-Fi WAN only | LAN clients browse and resolve DNS |
| Ethernet WAN only | LAN clients browse and resolve DNS |
| Both WAN paths | Documented priority or load-balancing behavior |
| Overlay disabled | Ordinary routing remains healthy |
| Private DNS unavailable | Public DNS path remains usable if policy permits |
| Cold boot | WAN, LAN, AP, firewall, and DNS recover without manual repair |
| Reconnect after upstream loss | Default route and NAT return automatically |

Test from a client behind the router, not only from the router shell. A router
may reach the internet while forwarding or NAT for LAN clients is broken.

## Hidden Automation Risk

Boot-time repair scripts can make intermittent problems harder to diagnose. A
repair service that rewrites wireless profiles or firewall state may race the
vendor control plane and produce a different configuration on each boot.

Prefer the stock control plane unless a reproducible defect requires a narrowly
scoped workaround. If a workaround is necessary:

- make it idempotent;
- log exactly what it changes;
- gate it on observed bad state;
- preserve a disable path;
- test cold boot, WAN failover, and ordinary UI changes;
- remove it when the upstream behavior is fixed.
