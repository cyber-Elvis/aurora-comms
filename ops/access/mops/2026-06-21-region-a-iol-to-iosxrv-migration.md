# MOP: Region A IOL to IOS-XRv 6.1.3 platform migration

## Change record

| Field | Value |
| --- | --- |
| Change ID | `CHG-AURORA-REG-A-XRV-001` |
| Date prepared | 2026-06-21 |
| Operator | Elvis |
| Coach / verifier | Codex |
| Project | `ops-lab` (`d8119db0-dd43-4d20-870d-9d62fd6345f1`) |
| Controller | `http://192.168.137.1:3080/v2` |
| Source platform | Cisco IOL 17.15 |
| Target platform | Cisco IOS-XRv 6.1.3 |
| Method | Rolling one-for-one platform migration |
| Expected impact | One POP at a time; MEL pair migration interrupts the current IS-IS/LDP adjacency |

## Objective

Replace the four Region A IOL routers with IOS-XRv 6.1.3 while preserving
the deployed addressing, management access, interface state, and existing
IS-IS/LDP behaviour.

This is a platform migration only. Do not add VPNv4, VRFs, new core addresses,
IPv6, ROV, or change router IDs during this MOP.

## Operator boundary

- Elvis types all IOS-XR console commands.
- Codex may add, start, stop, position, and link GNS3 nodes through the API.
- Codex may verify GNS3/API, host resources, ping, TCP/22, and read-only device
  state.
- Codex does not connect to or send input to a router console unless Elvis
  explicitly permits it.
- Do not have two clients attached to the same serial console.

## Reason for change

IOS-XRv provides IOS-XR operational practice that IOL cannot:

- transactional candidate configuration and `commit`;
- commit labels, comments, confirmed commits, and rollback;
- IOS-XR route-policy and service-provider CLI;
- IOS-XR process, logging, and troubleshooting workflow;
- `cisco.iosxr` and NETCONF-oriented automation practice.

IOL remains the rollback platform until all acceptance gates pass.

## Scope

| Migration order | Source | Target | Risk |
| --- | --- | --- | --- |
| 1 | `ADL-PE1-CISCO-IOL-RT01` | `ADL-PE1-CISCO-IOSXR-RT01` | Lowest: management only |
| 2 | `GEL-PE1-CISCO-IOL-RT01` | `GEL-PE1-CISCO-IOSXR-RT01` | Low: management + Loopback0 only |
| 3 | `MEL-PE1-CISCO-IOL-RT01` | `MEL-PE1-CISCO-IOSXR-RT01` | Medium: active MEL core link, IS-IS and LDP |
| 4 | `MEL-P-CISCO-IOL-RT01` | `MEL-P-CISCO-IOSXR-RT01` | Medium: completes XR-XR MEL pair |

## Explicit exclusions

- IOS-XRv9000 6.0.1
- IOS XR 7.x
- VPNv4 and L3VPN service activation
- GEL loopback renumbering from the deployed `10.0.0.3` to planned `10.0.0.5`
- ADL Loopback0 and the planned `10.0.0.6`
- MEL-PE1 to GEL and GEL to ADL core addressing
- Transit-A, Transit-B, CE, firewall, RPKI, and Region B changes
- deletion of IOL rollback nodes or saved configuration

## Pre-change evidence

### GNS3 and image

| Check | Expected / observed |
| --- | --- |
| Controller | `192.168.137.1:3080`, GNS3 `2.2.59` |
| XR template | `IOS-XRv-6.1.3`, ID `a1df1f44-44de-4745-a1d7-682b06aff43b` |
| Image | `iosxrv-k9-demo-6.1.3.qcow2` |
| Image MD5 | `1693b5d22a398587dd0fed2877d8dfac` |
| Image integrity | `qemu-img check`: no errors |
| XR allocation | 3072 MB RAM, 1 vCPU, four `e1000` adapters |
| Original link count | 8 |

### Backup

Created before any target nodes:

```text
PC2:
C:\Users\Elvis-PC\GNS3\projects\d8119db0-dd43-4d20-870d-9d62fd6345f1\
  ops-lab.pre-iosxrv-migration-20260621-134424.gns3.bak

PC2 project backup SHA256:
17D81A2CC89731C3D55CF2D862A5AFD8E38E92802E9D6EE3044CE9F2626D6FDE

GNS3 VM:
/opt/gns3/backups/
  ops-lab-pre-iosxrv-migration-20260621-134424.tar.gz

GNS3 VM backup SHA256:
6af5a16d6d5d37903160e946af3a32110d7edd37d2a368789ce855393ac12fc3
```

### Source configuration baseline

| Node | Deployed state to preserve |
| --- | --- |
| MEL-P | Lo0 `10.0.0.1/32`; core `10.255.0.0/31`; IS-IS L2; LDP; OOB `10.255.191.11/24` |
| MEL-PE1 | Lo0 `10.0.0.2/32`; core `10.255.0.1/31`; IS-IS L2; LDP; OOB `10.255.191.12/24` |
| GEL-PE1 | Lo0 `10.0.0.3/32`; core interfaces shut/unaddressed; OOB `10.255.191.15/24` |
| ADL-PE1 | No Loopback0; core interfaces shut/unaddressed; OOB `10.255.191.17/24` |

The migration intent is recorded in:

```text
ops/migration/region-a-iosxrv/intent.yml
```

## Staged target nodes

| Target | Node ID | Controller console | GNS3 VM serial console | Initial state |
| --- | --- | --- | --- | --- |
| ADL XR | `e84abeaa-c318-4d1f-9ba6-7f0b684f2481` | `5008` | `5008` | Started, unlinked |
| GEL XR | `778cb6a1-7b54-4879-9119-c1fb17f54ed2` | `5010` | `5010` | Stopped, unlinked |
| MEL-PE1 XR | `17bf20ab-df44-4acd-82a3-af36842b41f8` | `5012` | `5012` | Stopped, unlinked |
| MEL-P XR | `b29809e2-ced9-4b33-9ca8-0cf3803e613d` | `5014` | `5014` | Stopped, unlinked |

From PC3 Termius, open `PC2 GNS3 Jump`, then connect to the GNS3 VM console
proxy. For the ADL canary:

```bash
telnet 127.0.0.1 5008
```

## Canary gate: discover IOS-XRv interfaces

ADL is the canary. It is unlinked, so it cannot duplicate the active IOL
management address.

After IOS-XRv finishes booting, run:

```iosxr
terminal length 0
show version
show platform
show interfaces brief
show inventory
show configuration commit list
show ssh server
```

Record:

```text
Management interface:
Adapter 0 maps to:
Adapter 1 maps to:
Adapter 2 maps to:
Adapter 3 maps to:
XR prompt:
Boot time:
Supported SSH host/user key algorithms:
```

Stop. Do not paste the target configuration until the management and data
interface names are confirmed. Replace the interface placeholders in:

```text
ops/migration/region-a-iosxrv/configs/
```

On a factory-first boot, IOS-XRv may prompt before presenting the CLI:

```text
Enter root-system username:
Enter secret:
Enter secret again:
```

Use `admin` as the root-system username and enter the strong IOS-XR
break-glass secret interactively. IOS-XR does not use IOS `enable` mode or the
IOS command `enable algorithm-type scrypt secret`. Use the strongest
platform-native secret form accepted by IOS-XRv 6.1.3.

IOS-XRv 6.1.3 is old enough that Ed25519 user keys may not be available.
Confirm the supported SSH algorithms on the canary. If Ed25519 is unsupported,
generate a dedicated RSA 3072-bit automation key for this legacy XR zone;
do not weaken global SSH client policy and do not reuse a host-management key.

## Per-node implementation procedure

Perform the following sequence for one router only.

### 1. Capacity pre-check

On the GNS3 VM:

```bash
uptime
free -h
ps -eo pid,comm,%cpu,%mem,rss,args --sort=-rss | head -n 20
```

Go/no-go:

- available RAM at least 4 GiB before starting the next XR node;
- no swap or OOM event;
- five-minute load average below 2 before the next cold boot;
- GNS3 API and existing nodes responsive.

### 2. Start the target unlinked

Codex starts the target through the GNS3 API. Wait for IOS-XRv to finish
booting before opening its console.

### 3. Configure the target offline

Use the node-specific file under:

```text
ops/migration/region-a-iosxrv/configs/
```

Replace:

- `<XR_MGMT_IF>`;
- `<XR_CORE_EAST_IF>` and/or `<XR_CORE_WEST_IF>`;
- secret placeholders;
- public-key placeholders.

Use a labelled commit:

```iosxr
show configuration
commit label CHG-AURORA-REG-A-XRV-001
show configuration commit list
```

Do not connect the target to the management or core switches yet.

### 4. Offline target pre-check

```iosxr
show running-config
show interfaces brief
show configuration commit list
show configuration failed
```

Expected:

- hostname matches the IOS-XR target;
- final production addresses are present;
- all unlinked interfaces show down/down, not an error state;
- no failed configuration;
- commit label recorded.

### 5. Stop the target

Stop the configured XR node through the API before changing links.

### 6. Quiesce and stop the source

On the source IOL, Elvis captures:

```ios
show clock
show ip interface brief
show isis neighbors
show mpls ldp neighbor
show running-config | section ^interface|^router isis|^mpls ldp
show startup-config | include hostname
```

Then save:

```ios
write memory
```

Codex stops the source IOL through the API.

### 7. Rehome links

Codex deletes only that source node's links and recreates them against the
confirmed XR interfaces. Do not delete the source node.

Original link map:

| Source port | Peer |
| --- | --- |
| MEL-P `Ethernet0/0` | MEL-PE1 `Ethernet0/0` |
| MEL-P `Ethernet0/1` | MGMT-SW01 port 1 |
| MEL-PE1 `Ethernet0/1` | MGMT-SW01 port 2 |
| MEL-PE1 `Ethernet0/2` | GEL `Ethernet0/0` |
| GEL `Ethernet0/2` | ADL `Ethernet0/0` |
| GEL `Ethernet0/1` | MGMT-SW01 port 4 |
| ADL `Ethernet0/1` | MGMT-SW01 port 5 |

### 8. Start the XR target

Start only the migrated XR target. Wait for boot completion and protocol
settling before validation.

### 9. Post-change validation

Common:

```iosxr
show clock
show version
show platform
show interfaces brief
show route ipv4
show logging last 50
show configuration commit list
```

MEL-P and MEL-PE1:

```iosxr
show isis adjacency
show isis database
show mpls ldp neighbor
show mpls ldp bindings
show route 10.0.0.1/32
show route 10.0.0.2/32
```

External:

```bash
ping -c 3 <management-ip>
nc -vz -w 3 <management-ip> 22
```

Acceptance:

- management ping and SSH succeed through the GNS3 VM;
- interface state matches the source baseline;
- MEL IS-IS adjacency is Up after both sides are migrated;
- MEL LDP session is Operational after both sides are migrated;
- no unexpected route, duplicate-address, OOM, or GNS3 restart event;
- five-minute host load returns below 2 before the next migration.

## Backout

Back out immediately if:

- XR fails to boot or remains CPU-bound;
- GNS3 VM becomes unreachable;
- available RAM falls below 2 GiB;
- management cannot be restored within 15 minutes;
- MEL IS-IS/LDP cannot be restored within 15 minutes after the second MEL
  router is migrated;
- configuration parity cannot be demonstrated.

Procedure:

1. Stop the XR node.
2. Delete only its newly created links.
3. Recreate the source IOL links using the original link map.
4. Start the source IOL.
5. Confirm management, interfaces, and existing protocols.
6. Leave the XR node stopped and unlinked for diagnosis.

Do not delete either platform during backout.

## Evidence template

```text
Change ID: CHG-AURORA-REG-A-XRV-001
Node:
Operator:
Date/time:

PRE-CHECK
- Source node ID/state:
- Target node ID/state:
- Source startup config captured:
- GNS3 link count:
- VM RAM available:
- VM load average:

XR DISCOVERY
- Version:
- Platform:
- Management interface:
- Core interface mapping:
- Console port:

IMPLEMENTATION
- Target offline commit ID/label:
- Source stopped at:
- Links moved at:
- Target started at:
- Target boot-complete at:

POST-CHECK
- Management ping:
- TCP/22:
- SSH login:
- Interface parity:
- IS-IS adjacency:
- LDP neighbour:
- Route parity:
- VM RAM available:
- VM load average:
- Errors:

RESULT: PASS / FAIL / BACKED OUT
Notes:
```

## Closure

After all four routers pass:

1. run a 60-minute soak;
2. perform one controlled MEL link flap and verify reconvergence;
3. export the GNS3 project;
4. update inventory, diagrams, Region A plan, deployment status, and Ansible
   groups from `cisco.ios` to `cisco.iosxr`;
5. retain stopped IOL rollback nodes for seven days or until two successful
   lab sessions;
6. schedule MPLS L3VPN/VPNv4 as a separate MOP.

## Execution evidence

### Node 1 of 4 — ADL-PE1 — RESULT: PASS

| Field | Value |
| --- | --- |
| Date/time | 2026-06-21, ~04:57–05:01 UTC |
| Operator | Elvis (IOS-XR console); Claude (GNS3 API + read-only checks) |
| XR discovery | IOS-XR 6.1.3; prompt `RP/0/0/CPU0:ADL-PE1-CISCO-IOSXR-RT01#`; mgmt `MgmtEth0/0/CPU0/0`, core→GEL `Gi0/0/0/0`, data `Gi0/0/0/1-2`; no Ed25519 → RSA-2048 host key generated |
| Break-glass user | `labadmin` (group root-system); secret set interactively at first boot (`admin` is reserved/locked on XR) |
| Target offline commit | label `CHG-AURORA-REG-A-XRV-001` by `labadmin` |
| Source IOL | `write memory` OK, then stopped; rollback node + links retained |
| Links rehomed | `MGMT-SW01 p5 → ADL-XR a0/p0` (`MgmtEth0/0/CPU0/0`); `GEL-IOL Et0/2 → ADL-XR a1/p0` (`Gi0/0/0/0`) |
| Post-check | mgmt `10.255.191.17` ping 3/3 0% loss ~2 ms; TCP/22 OK; SSH `labadmin` login OK; parity = mgmt-only, no Lo0/IS-IS/LDP; VM ~17 GiB free, load <0.3 |
| Rollback retained | `ADL-PE1-CISCO-IOL-RT01` stopped + unlinked + config saved (keep 7 days / 2 sessions) |

Automation key (aurora-codex/aurora-claude RSA-3072 for the XR zone) deferred to the
access-hardening change after all four nodes are migrated.

### Node 2 of 4 — GEL-PE1 — RESULT: PASS

| Field | Value |
| --- | --- |
| Date/time | 2026-06-21, ~05:07–05:25 UTC |
| XR discovery | prompt `GEL-PE1-CISCO-IOSXR-RT01`; mgmt `MgmtEth0/0/CPU0/0`, core→MEL-PE1 `Gi0/0/0/0`, core→ADL `Gi0/0/0/1`; RSA-2048 host key |
| Offline commit | label `CHG-AURORA-REG-A-XRV-001` by `labadmin`; `Loopback0 10.0.0.3/32` preserved (no renumber), cores shut |
| Source IOL | `write memory` OK, no IS-IS/LDP neighbours, stopped; rollback retained |
| Links rehomed | `MGMT-SW01 p4 → GEL-XR a0/p0`; `MEL-PE1-IOL Et0/2 → GEL-XR a1/p0`; `ADL-XR Gi0/0/0/0 → GEL-XR a2/p0` (GEL↔ADL now XR↔XR) |
| Post-check | mgmt `10.255.191.15` ping 3/3 0% loss; TCP/22 OK; SSH `labadmin` login OK (new RSA host key accepted) |
| Rollback retained | `GEL-PE1-CISCO-IOL-RT01` stopped + unlinked + saved |

### Node 3 of 4 — MEL-PE1 — RESULT: PASS

| Field | Value |
| --- | --- |
| Date/time | 2026-06-21, ~05:35–08:08 UTC |
| IS-IS/LDP parity verified vs IOL | net `49.0001.0000.0000.0002.00`, is-type level-2-only, metric-style wide, Lo0 passive, LDP router-id 10.0.0.2 |
| Offline commit | label `CHG-AURORA-REG-A-XRV-001`; `Lo0 10.0.0.2`, mgmt `10.255.191.12`, core→MEL-P `Gi0/0/0/0` `10.255.0.1/31` IS-IS+LDP, core→GEL `Gi0/0/0/1` shut |
| Links rehomed | `MGMT-SW01 p2 → a0/p0`; `MEL-P-IOL Et0/0 → a1/p0` (Gi0/0/0/0); `GEL-XR Gi0/0/0/0 → a2/p0` (GEL↔MEL-PE1 now XR↔XR) |
| Post-check (from MEL-P IOL) | mgmt `10.255.191.12` ping/TCP-22 OK; **IS-IS L2 adjacency UP** XR↔IOL; **LDP Oper**; `10.0.0.2/32` learned `i L2 [115/10]` — adjacency re-formed across platform change |
| Rollback retained | `MEL-PE1-CISCO-IOL-RT01` stopped + unlinked + saved |

### Node 4 of 4 — MEL-P — RESULT: PASS

| Field | Value |
| --- | --- |
| Date/time | 2026-06-21, ~08:09–09:05 UTC |
| IS-IS/LDP parity verified vs IOL | net `49.0001.0000.0000.0001.00`, is-type level-2-only, metric-style wide, Lo0 passive, LDP router-id 10.0.0.1 |
| Offline commit | label `CHG-AURORA-REG-A-XRV-001`; `Lo0 10.0.0.1`, mgmt `10.255.191.11`, core→MEL-PE1 `Gi0/0/0/0` `10.255.0.0/31` IS-IS+LDP |
| Links rehomed | `MGMT-SW01 p1 → a0/p0`; `MEL-PE1-XR Gi0/0/0/0 → a1/p0` (core now **XR↔XR**) |
| Post-check (on MEL-P XR) | mgmt `10.255.191.11` ping/TCP-22 OK; **IS-IS L2 adjacency Up** to MEL-PE1 (`Gi0/0/0/0` PtoP); **LDP Oper** to `10.0.0.2`; route `i L2 10.0.0.2/32 [115/10]`; `Lo0 10.0.0.1` + core `10.255.0.0/31` present |
| Rollback retained | `MEL-P-CISCO-IOL-RT01` stopped + unlinked + saved |

## Migration status: COMPLETE (4/4) — 2026-06-21

All four Region A routers are IOS-XRv 6.1.3 with deployed-state parity (addresses,
Loopbacks, IS-IS L2 + LDP). GNS3 link endpoints relabeled to real XR interface names.
IOL rollback nodes retained (stopped, unlinked, saved) until 2026-06-28 or two clean
lab sessions.

### Closure checklist (remaining)
- [ ] 60-minute soak (no OOM/restart, adjacency stable)
- [ ] one MEL core link-flap → verify IS-IS/LDP reconvergence
- [ ] export GNS3 project
- [ ] update inventory.yml / diagrams / region-a-plan / deployment-status; Ansible `cisco.ios` → `cisco.iosxr`
- [ ] post-migration access hardening: dedicated RSA-3072 aurora-codex/aurora-claude keys on the XR zone; remove personal `id_ed25519` from GEL (ADR-004 deviation)
- [ ] schedule separate MPLS L3VPN / VPNv4 MOP

