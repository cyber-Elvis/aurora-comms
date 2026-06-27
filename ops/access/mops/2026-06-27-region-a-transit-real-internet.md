# MOP: Region A - real internet via transit nodes

## Change record

| Field | Value |
| --- | --- |
| Change ID | `CHG-AURORA-REG-A-TRANSIT-REAL-INET` |
| Date | 2026-06-27 |
| Operator | Elvis (drives IOS-XE transit sessions from PC3/Termius) |
| Coach / verifier | Codex (GNS3 topology correction, Ansible apply through PC1 WSL, verification evidence) |
| Scope | Give `transit-a-csr` and `transit-b-iol` real IPv4 internet egress and PAT lab traffic through the active transit default path. |
| Blast radius | Transit IOS-XE nodes only plus the GNS3 Cloud uplink link. Existing PE eBGP, iBGP, IS-IS, and LDP are unchanged. |
| Rollback | Remove NAT/uplink interface config, restore Null0 default if returning to mock-only internet, or move the GNS3 Cloud back to the prior port. |

## Outcome

The interrupted `c48e437d...` session created the physical GNS3 plumbing but chose `eth0`.
Follow-up verification showed the VM's actual internet default route is on `eth1`
(`192.168.191.0/24`, gateway `192.168.191.2`), while `eth0` is only on
`192.168.20.0/24` with no default route.

Corrected topology, verified 2026-06-27:

```text
GNS3 VM eth1 (192.168.191.0/24, default via 192.168.191.2)
  -> INET-UPLINK-eth1 (Cloud)
  -> INET-SW
     -> transit-a-csr GigabitEthernet3
     -> transit-b-iol Ethernet0/2
```

When transit eBGP is active, the default route can now resolve through DHCP on the
real uplink instead of a Null0 placeholder, and outbound lab traffic can be PATed
to the transit's DHCP address on the internet-facing interface. Current 2026-06-27
verification from the transit nodes returned `% BGP not active`; PE/customer internet
verification remains gated on the transit eBGP stages in
`2026-06-25-region-a-transit-edge-config.md`.

## Design notes

- IPv4 only in this stage. The GNS3 VM's confirmed internet path is IPv4; do not change the
  existing IPv6 mock default until a real IPv6 uplink exists.
- NAT is done on the transit nodes, not the PEs. The PEs keep the provider-edge model:
  they learn a default route from the transits and send internet-bound traffic that way.
- Remove only the IPv4 Null0 default on the transits. Keep the mock `192.0.2.0/24` /28
  routes and the IPv6 `::/0` / `2001:DB8:A::/48` Null0 routes unless/until the mock
  internet exercise is retired.
- The NAT ACL intentionally permits RFC1918 plus documentation/public-test blocks used
  in the lab. This allows Region A/Region B loopbacks, infra links, and customer demo
  prefixes to reach real IPv4 internet while still translating them at the edge.

## Stage 1 - GNS3 uplink state

Already completed by Codex through the GNS3 controller:

```text
Deleted old link:
  INET-UPLINK-eth0:eth0 <-> INET-SW:Ethernet0

Renamed Cloud:
  INET-UPLINK-eth0 -> INET-UPLINK-eth1

Created corrected link:
  INET-UPLINK-eth1:eth1 <-> INET-SW:Ethernet0

Existing transit links preserved:
  INET-SW:Ethernet1 <-> transit-a-csr:GigabitEthernet3
  INET-SW:Ethernet2 <-> transit-b-iol:Ethernet0/2
```

Generated 4K topology diagram:

```text
docs/region-a-transit-internet-topology.svg
docs/region-a-transit-internet-topology.png
docs/projector/region-a-transit-internet/00-overview.png
docs/projector/region-a-transit-internet/01-topology.png
docs/projector/region-a-transit-internet/02-reference-interfaces.png
docs/projector/region-a-transit-internet/03-reference-operations.png
```

## Stage 2 - Ansible execution path

Applied 2026-06-27 from PC1 WSL Ubuntu using the repo Ansible control tree:

```text
ops/automation-iosxe/playbooks/real-internet.yml
```

The playbook uses the existing `transit` inventory, vault-backed `labadmin` credential,
and ProxyJump through `gns3@100.118.0.46`. Host-specific interface bindings are in:

```text
ops/automation-iosxe/host_vars/transit-a.yml
ops/automation-iosxe/host_vars/transit-b.yml
```

Final idempotent run:

```text
transit-a : ok=9 changed=0 unreachable=0 failed=0 skipped=3
transit-b : ok=9 changed=0 unreachable=0 failed=0 skipped=3
```

Verification evidence from that run:

```text
transit-a-csr GigabitEthernet3: 192.168.191.129/24 via DHCP, up/up
  default route: 0.0.0.0/0 via 192.168.191.2
  ping 1.1.1.1 source GigabitEthernet3: 100 percent (5/5)
  ping 8.8.8.8 source GigabitEthernet3: 100 percent (5/5)
  NAT outside: GigabitEthernet3; NAT inside: GigabitEthernet2

transit-b-iol Ethernet0/2: 192.168.191.130/24 via DHCP, up/up
  default route: 0.0.0.0/0 via 192.168.191.2
  ping 1.1.1.1 source Ethernet0/2: 100 percent (5/5)
  ping 8.8.8.8 source Ethernet0/2: 100 percent (5/5)
  NAT outside: Ethernet0/2; NAT inside: Ethernet0/0
```

Note: the first apply completed the config changes but the immediate ping verification
raced DHCP. The playbook now waits for the outside interface to show `DHCP` and `up`
before collecting ping evidence.

## Manual equivalent - transit-a-csr IOS-XE config

Paste on `transit-a-csr` as `labadmin`:

```text
configure terminal
!
no ip route 0.0.0.0 0.0.0.0 Null0
!
ip name-server 1.1.1.1 8.8.8.8
!
ip access-list standard AURORA-LAB-NAT
 permit 10.0.0.0 0.255.255.255
 permit 172.16.0.0 0.15.255.255
 permit 192.168.0.0 0.0.255.255
 permit 192.0.2.0 0.0.0.255
 permit 198.51.100.0 0.0.0.255
 permit 203.0.113.0 0.0.0.255
exit
!
interface GigabitEthernet2
 description to-MEL-PE1 Gi0/0/0/2 (Aurora AS64496) TRANSIT-A
 ip nat inside
exit
!
interface GigabitEthernet3
 description REAL-INTERNET uplink via GNS3 INET-SW -> VM eth1
 ip address dhcp
 ip nat outside
 no shutdown
exit
!
ip nat inside source list AURORA-LAB-NAT interface GigabitEthernet3 overload
end
write memory
```

## Manual equivalent - transit-b-iol IOS-XE config

Paste on `transit-b-iol` as `labadmin`:

```text
configure terminal
!
no ip route 0.0.0.0 0.0.0.0 Null0
!
ip name-server 1.1.1.1 8.8.8.8
!
ip access-list standard AURORA-LAB-NAT
 permit 10.0.0.0 0.255.255.255
 permit 172.16.0.0 0.15.255.255
 permit 192.168.0.0 0.0.255.255
 permit 192.0.2.0 0.0.0.255
 permit 198.51.100.0 0.0.0.255
 permit 203.0.113.0 0.0.0.255
exit
!
interface Ethernet0/0
 description to-ADL-PE1 Gi0/0/0/1 (Aurora AS64496) TRANSIT-B
 ip nat inside
exit
!
interface Ethernet0/2
 description REAL-INTERNET uplink via GNS3 INET-SW -> VM eth1
 ip address dhcp
 ip nat outside
 no shutdown
exit
!
ip nat inside source list AURORA-LAB-NAT interface Ethernet0/2 overload
end
write memory
```

## Manual transit verification

Run on `transit-a-csr`:

```text
show ip interface brief | include GigabitEthernet3
show ip route 0.0.0.0
show ip nat statistics
ping 1.1.1.1 source GigabitEthernet3
ping 8.8.8.8 source GigabitEthernet3
show ip bgp 0.0.0.0
```

Run on `transit-b-iol`:

```text
show ip interface brief | include Ethernet0/2
show ip route 0.0.0.0
show ip nat statistics
ping 1.1.1.1 source Ethernet0/2
ping 8.8.8.8 source Ethernet0/2
show ip bgp 0.0.0.0
```

Expected:

- The uplink interface has a DHCP address on `192.168.191.0/24`.
- `show ip route 0.0.0.0` resolves through DHCP, normally via `192.168.191.2`.
- Internet pings sourced from the uplink interface succeed.
- `network 0.0.0.0 mask 0.0.0.0` remains valid in BGP because the DHCP default is now
  the real route backing it.

## Downstream Aurora/lab verification

From MEL-PE1, after Transit-A is established and preferred:

```text
show bgp ipv4 unicast 0.0.0.0/0
show route 0.0.0.0/0
ping 1.1.1.1 source Loopback0
traceroute 1.1.1.1 source Loopback0
```

From ADL-PE1, after Transit-B is established:

```text
show bgp ipv4 unicast 0.0.0.0/0
show route 0.0.0.0/0
ping 1.1.1.1 source Loopback0
traceroute 1.1.1.1 source Loopback0
```

Then on the active transit, confirm PAT is being used:

```text
show ip nat translations
show ip nat statistics
```

Note: a P-only node with no BGP default will not automatically get internet just because the
PEs do. For P-node management-plane internet tests, add an explicit static/default path or
run the test from a PE/CE/customer node that receives the transit default.

## Rollback

Transit-A:

```text
configure terminal
no ip nat inside source list AURORA-LAB-NAT interface GigabitEthernet3 overload
interface GigabitEthernet3
 no ip address dhcp
 no ip nat outside
 shutdown
exit
interface GigabitEthernet2
 no ip nat inside
exit
no ip access-list standard AURORA-LAB-NAT
ip route 0.0.0.0 0.0.0.0 Null0
end
write memory
```

Transit-B:

```text
configure terminal
no ip nat inside source list AURORA-LAB-NAT interface Ethernet0/2 overload
interface Ethernet0/2
 no ip address dhcp
 no ip nat outside
 shutdown
exit
interface Ethernet0/0
 no ip nat inside
exit
no ip access-list standard AURORA-LAB-NAT
ip route 0.0.0.0 0.0.0.0 Null0
end
write memory
```
