# Aurora — Multi-Vendor Configuration Comparison

| Field | Value |
| --- | --- |
| Document version | 1.0 |
| Status | Active — covers W1 baseline (IS-IS + MPLS-LDP + iBGP) |
| Last updated | May 2026 |

## Purpose

The same network engineering intent expressed across three vendors:

- **FRR** — the lab's deploy target. Open source, container-native; runs in production at Facebook, LinkedIn, Equinix.
- **Cisco IOS-XR** — carrier-grade Cisco platform; what most enterprise-side ISPs and large enterprises deploy.
- **Nokia SR OS classic CLI** — Nokia 7750 SR series; matches the operator's five years of production experience.

The protocol behaviour is identical across all three; only the syntax differs. This document is the dictionary that lets you read any of the three and recognise what's happening.

Reference configurations live in `lab/manual/{frr,cisco-ios,nokia-sros}/<router>.{conf,cfg,cli}`. The data they encode is identical; the dialect differs.

## Section index

1. Hostname
2. Loopback (router identity)
3. P2P backbone interface
4. IS-IS process
5. IS-IS interface enrollment
6. MPLS LDP process
7. iBGP peer group
8. iBGP individual neighbour + AF activation
9. Verification — equivalent show commands
10. Vendor philosophy

---

## 1. Hostname

### FRR

    hostname melbourne

### Cisco IOS-XR

    hostname melbourne

### Nokia SR OS

    configure system
        name "melbourne"
    exit

(Nokia keeps system identity in the system context, not the router context.)

---

## 2. Loopback (router identity)

### FRR

    interface lo
     ip address 10.0.0.1/32
     ip router isis CORE
     isis circuit-type level-2-only

IS-IS enrollment is set on the interface itself.

### Cisco IOS-XR

    interface Loopback0
     description router-id
     ipv4 address 10.0.0.1 255.255.255.255

IOS-XR enrolls the interface in IS-IS under the `router isis` block, not here.

### Nokia SR OS

    configure router "Base"
        interface "system"
            description "router-id"
            address 10.0.0.1/32
            no shutdown
        exit

Nokia uses a special `system` interface name — that *is* the loopback. Every active component requires `no shutdown`.

---

## 3. P2P backbone interface

### FRR

    interface eth1
     description to-sydney
     ip address 10.1.12.0/31
     ip router isis CORE
     isis network point-to-point
     isis circuit-type level-2-only
     mpls ldp

Single interface block holds everything.

### Cisco IOS-XR

    interface GigabitEthernet0/0/0/0
     description to-sydney
     ipv4 address 10.1.12.0/31

IS-IS network type, level, and MPLS-LDP enrolment are configured under `router isis` and `mpls ldp` blocks separately.

### Nokia SR OS

    configure router "Base"
        interface "to-sydney"
            port 1/1/1
            address 10.1.12.0/31
            no shutdown
        exit

Nokia uses **named interfaces** like `"to-sydney"` mapped to physical ports `1/1/1`. IS-IS and LDP are applied under their respective contexts later.

---

## 4. IS-IS process

### FRR

    router isis CORE
     net 49.0001.0010.0000.0001.00
     is-type level-2-only
     metric-style wide
     lsp-gen-interval 5

### Cisco IOS-XR

    router isis CORE
     net 49.0001.0010.0000.0001.00
     is-type level-2-only
     address-family ipv4 unicast
      metric-style wide
     !

IOS-XR puts metric style under `address-family`. This allows separate metric configuration per address family (IPv4 vs IPv6).

### Nokia SR OS

    configure router "Base"
        isis
            level-capability level-2
            area-id 49.0001
            system-id 0010.0000.0001
            level 2
                wide-metrics-only
            exit
            no shutdown
        exit

Nokia splits the NET into separate `area-id` and `system-id` lines. Metric style goes under `level 2`.

---

## 5. IS-IS interface enrollment

### FRR

Configured directly on each interface (`ip router isis CORE` lines under each `interface`). Already shown above.

### Cisco IOS-XR

    router isis CORE
     interface Loopback0
      passive
      address-family ipv4 unicast
      !
     !
     interface GigabitEthernet0/0/0/0
      point-to-point
      address-family ipv4 unicast
      !
     !

All interfaces enrolled in IS-IS appear under `router isis CORE`. Loopback is `passive` (no IS-IS hellos sent).

### Nokia SR OS

    configure router "Base"
        isis
            interface "system"
                passive
                no shutdown
            exit
            interface "to-sydney"
                interface-type point-to-point
                level-capability level-2
                no shutdown
            exit
            ...
        exit

---

## 6. MPLS LDP process

### FRR

    mpls ldp
     router-id 10.0.0.1
     !
     address-family ipv4
      discovery transport-address 10.0.0.1
      interface eth1
      interface eth2
      interface eth3
     exit-address-family
     !
    !

### Cisco IOS-XR

    mpls ldp
     router-id 10.0.0.1
     address-family ipv4
     !
     interface GigabitEthernet0/0/0/0
     !
     interface GigabitEthernet0/0/0/1
     !
     interface GigabitEthernet0/0/0/2
     !
    !

### Nokia SR OS

    configure router "Base"
        ldp
            interface-parameters
                interface "to-sydney"
                    no shutdown
                exit
                interface "to-geelong"
                    no shutdown
                exit
                interface "to-brisbane"
                    no shutdown
                exit
            exit
            no shutdown
        exit

Nokia auto-derives the LDP transport address from the `system` interface unless explicitly overridden.

---

## 7. iBGP peer group

This is where the three vendors look most different. Same concept, three names: **peer-group** (FRR), **neighbor-group** (Cisco IOS-XR), **group** (Nokia).

### FRR

    router bgp 65100
     bgp router-id 10.0.0.1
     no bgp ebgp-requires-policy
     neighbor IBGP_PE peer-group
     neighbor IBGP_PE remote-as 65100
     neighbor IBGP_PE update-source lo
     neighbor 10.0.0.2 peer-group IBGP_PE
     neighbor 10.0.0.3 peer-group IBGP_PE
     neighbor 10.0.0.4 peer-group IBGP_PE

### Cisco IOS-XR

    router bgp 65100
     bgp router-id 10.0.0.1
     address-family ipv4 unicast
     !
     neighbor-group IBGP_PE
      remote-as 65100
      update-source Loopback0
      address-family ipv4 unicast
       next-hop-self
      !
     !
     neighbor 10.0.0.2
      use neighbor-group IBGP_PE
     !
     ...

### Nokia SR OS

    configure router "Base"
        bgp
            router-id 10.0.0.1
            group "IBGP_PE"
                type internal
                peer-as 65100
                local-address system
                family ipv4
                next-hop-self
                neighbor 10.0.0.2
                exit
                neighbor 10.0.0.3
                exit
                neighbor 10.0.0.4
                exit
            exit
            no shutdown
        exit

The pattern is identical across vendors: **define shared settings once, attach individual neighbours**.

---

## 8. iBGP address-family activation

### FRR

    address-family ipv4 unicast
     network 10.0.0.1/32
     neighbor IBGP_PE activate
     neighbor IBGP_PE next-hop-self
    exit-address-family

FRR requires explicit `activate` per neighbour per address family.

### Cisco IOS-XR

Activation is implicit — being a member of a `neighbor-group` that has an `address-family ipv4 unicast` block is the activation.

### Nokia SR OS

    family ipv4
    next-hop-self

Set under the group block. Implicit activation for any neighbour in the group.

---

## 9. Verification — equivalent show commands

| Concept | FRR (vtysh) | Cisco IOS-XR | Nokia SR OS |
| --- | --- | --- | --- |
| IS-IS adjacencies | `show isis neighbor` | `show isis neighbors` | `show router isis adjacency` |
| IS-IS database | `show isis database` | `show isis database` | `show router isis database` |
| MPLS LDP neighbours | `show mpls ldp neighbor` | `show mpls ldp neighbor` | `show router ldp session` |
| MPLS LDP bindings | `show mpls ldp binding` | `show mpls ldp bindings` | `show router ldp bindings` |
| BGP peer summary | `show ip bgp summary` | `show bgp summary` | `show router bgp summary` |
| BGP RIB | `show ip bgp` | `show bgp ipv4 unicast` | `show router bgp routes` |
| IP routing table | `show ip route` | `show route ipv4` | `show router route-table` |
| Interface state | `show interface brief` | `show ipv4 interface brief` | `show router interface` |

---

## 10. Vendor philosophy

**FRR — flat, Linux-style.** Every block is small. Comments use `!`. Configuration sits in a single `frr.conf` file. Fast to read once you know the protocol; less hierarchical structure than commercial vendors.

**Cisco IOS-XR — hierarchical with `!` exits.** Configuration nests deeply (`router isis` → `interface` → `address-family ipv4 unicast`). Explicit `!` exits each block. Address families are first-class containers. Modular but verbose.

**Nokia SR OS classic — named contexts with `exit`/`exit all`.** Every block has a name in quotes (`"system"`, `"IBGP_PE"`, `"to-sydney"`). Every active component requires `no shutdown`. `exit all` returns to operational mode. Verbose but extremely explicit — you always know which context you are in. (Modern SR OS 22+ ships with MD-CLI as an alternative; this document uses classic CLI to match production operator experience.)

## Implications for automation

The three vendors are syntactically different but semantically identical at the protocol level. **Each new feature lands in three vendor flavours, but the underlying intent is one piece of data.** That single data structure (loopback, NET, interface IPs, peers) becomes a YAML file in `host_vars/<router>.yml` once Ansible automation lands. The Jinja2 template per vendor is exactly the work this `compare.md` document encodes — except encoded as code rather than prose.

When you read `lab/manual/cisco-ios/melbourne.cfg`, what you're seeing is what `templates/cisco-ios.j2` would render given Melbourne's `host_vars` data. The "manual mirror, then automation" flow we use in this lab makes that connection visible.

## Generator

The 12 router configs in `lab/manual/` are produced by `lab/manual/gen_vendor_configs.py`. Re-run the generator after any change to the `ROUTERS` dictionary inside it. This is the manual analogue of `make render` in the upcoming Ansible workflow.
