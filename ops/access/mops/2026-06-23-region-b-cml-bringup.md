# MOP: Region B — stand up on DevNet CML (initial bring-up)

## Change record

| Field | Value |
| --- | --- |
| Change ID | `CHG-AURORA-REG-B-CML-001` |
| Date | 2026-06-23 |
| Driver / operator | Elvis (drives DevNet portal, VPN credential entry, router consoles) |
| Coach / verifier | Claude (provides commands → PC3 clipboard; verifies read-only from PC1 WSL) |
| Region | B — Cisco-dominant (+Juniper BYOI), ephemeral DevNet CML |
| Artifacts | `ops/region-b-cml/` (topology, addressing, inventory); this MOP |
| Reference | ADR-002 §3.2/§3.3, ADR-003 §2.3, `docs/devnet-resource-strategy.md` |
| Blast radius | None local. Region A is untouched until Step 8 (inter-region eBGP). |

## Why

Build Region B in parallel with the in-progress Region A. CML compute is Cisco's
(only during a reservation), so this contends for **zero** Dell GNS3 RAM/CPU. The
region is rebuilt from `ops/region-b-cml/topology/aurora-region-b.yaml` each reservation.

## Prerequisites (verify before starting)

| # | Item | Check |
| --- | --- | --- |
| P1 | Cisco CCO + DevNet account | login at developer.cisco.com works |
| P2 | openconnect present on PC1 WSL | confirmed: `/usr/sbin/openconnect` (2026-06-23) |
| P3 | No conflicting tun0 on PC1 WSL | `ip -br addr show tun0` → none |
| P4 | Vault break-glass secret available | `~/.aurora-vault-pass` present; `__LABADMIN_SECRET__` known |
| P5 | (BYOI, Step 7a) **vJunos-router** qcow2 staged — the ONLY CML upload | image path known |
| P6 | (Step 7b) Local CEs runnable: PA-VM 9.0.4 on PC1 vrnetlab, vSRX on Dell, Aruba CX | reachable via the bridge |

> **Clipboard delivery:** every pasteable command below is pushed to **PC3** as a
> Win+V history entry (the dedicated terminal box; you reach PC1 WSL / CML through PC3
> Termius). Portal clicks and credential entry are written steps — not pasteable.

---

## Step 1 — Reserve Cisco Modeling Labs (operator, DevNet portal)

1. https://devnetsandbox.cisco.com → search **"Cisco Modeling Labs"** (Reservable).
2. **Reserve** (8h default / 2d max). Provisioning ≈ 9 min; watch for the email/portal panel.
3. When ready, the panel shows: **VPN host\:port, VPN username, VPN password**, and the
   **CML controller URL + credentials**. Capture them (next step records into the inventory).

Fallbacks if CML is queue-exhausted/maintenance: SD-WAN-embedded CML at `10.10.20.161`,
then XRd Sandbox, then local IOS-XRv (see `devnet-resource-strategy.md` §4).

## Step 2 — Bring up the openconnect bridge (operator types creds; runs on PC1 WSL)

Pasteable (pushed to PC3 — runs inside a PC1 WSL shell). Replace `<...>` is **not** needed:
the operator pastes, then types the VPN password and accepts the cert interactively.

```bash
# In PC1 WSL (the bridge MUST live here per ADR-002 §6):
sudo openconnect --protocol=anyconnect <VPN_HOST>:<VPN_PORT> --user=<VPN_USER>
# leave running in this shell; enter password + accept cert when prompted
```

## Step 3 — Verify the bridge + CML reachability (Claude, read-only from PC1 WSL)

```bash
ip -br addr show tun0                       # expect a tun0 with an address
ping -c2 <CML_HOST>                         # CML controller reachable over tunnel
curl -ksS https://<CML_HOST>/api/v0/authok  # TLS reaches CML API
```

Record the assigned reservation values into the gitignored live inventory:

```bash
cd /mnt/d/CyberLab/Repos/aurora-comms/ops/region-b-cml/ansible
cp inventory/devnet-current.example.yml inventory/devnet-current.yml
# edit cml_url / cml_username / per-node mgmt IPs; vault-encrypt the passwords
```

## Step 4 — Confirm schema/node-defs, render secrets, import topology (operator + Claude)

1. **Verify node-definition slugs** the reservation actually exposes (Claude, read-only):
   ```bash
   curl -ksS -u <CML_USER>:<CML_PASS> https://<CML_HOST>/api/v0/node_definitions \
     | python3 -c 'import sys,json;[print(d["id"]) for d in json.load(sys.stdin)]'
   ```
   Confirm `iosxrv9000`, `cat8000v` exist; note the real slugs for PA-VM/vJunos/vSRX
   (created in Step 7). Fix `node_definition`/interface labels in the topology if they differ.
2. **Render the break-glass secret** into a working copy (gitignored, not committed):
   ```bash
   cd /mnt/d/CyberLab/Repos/aurora-comms/ops/region-b-cml/topology
   sed "s/__LABADMIN_SECRET__/$(cat ~/.aurora-labadmin-secret)/g" \
     aurora-region-b.yaml > aurora-region-b.rendered.yaml
   ```
3. **Import** `aurora-region-b.rendered.yaml` via CML UI (Import) or API. If the controller
   rejects `lab.version`, build from this file as the spec in the UI, then **export the
   controller YAML back over `aurora-region-b.yaml`** and commit it as the new canonical.

## Step 5 — Boot the native-Cisco core in waves (operator) + verify (Claude)

Boot order (let each settle; ~150-250ms RTT from AU):
1. **Wave 1:** `DC-P-R1`, `DC-P-R2` (P core / RRs).
2. **Wave 2:** `MR-PE-R1`, `MR-PE-R2`, `HH-PE-R1`, `HH-PE-R2`.
3. **Wave 3:** `MR-CE`.

Per-XR-node one-time SSH key gen (operator, on each XR console after boot):
```
crypto key generate rsa
```

Verify (Claude, read-only via SSH over the bridge once mgmt IPs are up):
- `show isis adjacency` → Level-2 Up on every core /31.
- `show mpls ldp neighbor` → LDP Oper on every core /31.
- `show route 10.0.20.0/24` → all loopbacks learned (IS-IS).
- IOS XE peers (`MR-PE-R2`): `show isis neighbors`, `show mpls ldp neighbor`.

## Step 6 — Push service config via Ansible (operator runs from WSL; Claude verifies)

iBGP VPNv4 (RR cluster on DC-P pair), PE-CE eBGP, VRFs MAPLE-RIDGE/HELIX-HEALTH —
config-as-code, mirroring `ops/automation-iosxrv/`. Run from the WSL Ansible control node:

```bash
cd /mnt/d/CyberLab/Repos/aurora-comms/ops/region-b-cml/ansible
ansible-inventory -i inventory/devnet-current.yml --graph         # sanity
ansible region_b_iosxr -m cisco.iosxr.iosxr_command -a "commands='show version'"  # reachability
# then the service playbooks (authored once core is proven):
# ansible-playbook playbooks/ibgp-vpnv4.yml
# ansible-playbook playbooks/pe-ce-ebgp.yml
```

Verify: `show bgp vpnv4 unicast summary` (PEs ↔ RRs Established), CE prefixes in VRFs.

## Step 7 — Juniper vJunos (the one BYOI) + bridge the local non-Cisco CEs

Per the hosting principle (`addressing.md` §0): only vJunos is a CML upload; PA-VM, vSRX and
Aruba CX run locally and are bridged in.

### 7a — vJunos-router BYOI into CML (operator uploads; Claude verifies)

One-time per reservation: create a `vjunos-router` node definition + upload the qcow2 (UI:
Tools → Node/Image Definitions, or script with `virl2_client`/`cmlutils`). `JNX-P` is already
in the topology — once the image exists it boots. Then configure (junos collection): lo0
`10.0.20.31`, `ge-0/0/0` `10.255.20.15/31` (DC-P-R1), `ge-0/0/1` `10.255.20.17/31` (DC-P-R2),
IS-IS L2 area 49.0002 + LDP + iBGP to RRs. Verify: XR↔Junos IS-IS adjacency Up; iBGP to RRs
Established.

### 7b — Bring up local CEs and bridge them to the CML PEs (operator; Claude verifies)

The `EXT-HELIX-BR` → `EXT-CONN` external connector in the topology is the egress; set
`EXT-CONN`'s bridge to the reservation's outbound network so the CML HH-PE pair can reach the
locally-hosted CEs over the openconnect+MASQUERADE bridge.

| CE | Host | Bring-up | PE-CE session |
| --- | --- | --- | --- |
| `HH-CE` PA-VM 9.0.4 | **PC1 vrnetlab** (`vrnetlab/paloalto_pa-vm:9.0.4`) | start container; default admin/admin; config zones + eBGP (panos collection) | eBGP `64521` to HH-PE-R1 (`10.255.21.10`) + HH-PE-R2 (`10.255.21.14`), LOCAL_PREF |
| `JNX-FW` vSRX | **Dell standalone** | boot vSRX in Dell GNS3; security zones + eBGP | eBGP `64522` to HH-PE-R2 (`10.255.21.18`) — optional |
| `helix-lan-sw` Aruba CX | **PC1 / local** | local L2 behind `HH-CE` | local link (no GRE — CE is co-located) |

Verify (Claude, read-only): on HH-PE-R1/R2 `show bgp vrf HELIX-HEALTH summary` → PA-VM CE
Established, prefixes learned; end-to-end VRF ping across the bridge.

## Step 8 — Inter-region eBGP to Region A (operator + Claude; **only step that touches Region A**)

Plain eBGP `64496 (Region A) ↔ 65002 (Region B)` across the openconnect boundary
(addressing.md §6), global IPv4 unicast, Option A only (no MPLS label transfer across the
openconnect+MASQUERADE NAT). Region A end = `MEL-PE1` (the inter-region ASBR / border router;
`MEL-P` is the pure-P transport handoff that carries this to the bridge, not the BGP border);
Region B end = `DC-P-R1` (ASBR). Neighbor addresses = tun0/MASQUERADE (A side) + CML node (B side),
recorded in `devnet-current.yml`. Verify route exchange both directions; confirm Region A
sessions otherwise unchanged.

---

## Verification matrix

| Check | Command | Expected |
| --- | --- | --- |
| Bridge up | `ip -br addr show tun0` | tun0 with address |
| CML API | `curl -ksS https://<CML_HOST>/api/v0/authok` | 200 |
| IS-IS core | `show isis adjacency` | all core /31 adjacencies Up (L2) |
| LDP core | `show mpls ldp neighbor` | Oper on all core /31 |
| Loopbacks | `show route 10.0.20.0/24` | all RR/PE loopbacks present |
| iBGP VPNv4 | `show bgp vpnv4 unicast summary` | PEs↔RRs Established |
| PE-CE | `show bgp vrf MAPLE-RIDGE summary` | CE neighbors Up, prefixes learned |
| Multivendor | `show isis adjacency` (incl. JNX-P) | XR↔Junos adjacency Up |
| Inter-region | `show bgp summary` (ASBR) | 64496↔65002 Established, routes both ways |

## Evidence template (capture per check into `ops/access/evidence/2026-06-23-region-b-cml-bringup.md`)

```
[<UTC>] <node> <command>
<paste output>
RESULT: PASS|FAIL — <note>
```

## Rollback / teardown

Region B is ephemeral by design:
1. (If Step 8 done) Remove the inter-region eBGP neighbor on the Region A end — restores
   pre-change Region A state. This is the only persistent change to roll back.
2. Stop nodes / **release the CML reservation** in the DevNet portal.
3. Tear down the bridge: `Ctrl-C` the openconnect shell on PC1 WSL; confirm `tun0` gone.
4. `devnet-current.yml` is gitignored — delete it or leave for the next reservation’s edit.

Nothing on the Dell GNS3 host or Region A persists from this change except the Step-8
neighbor, which Step-1 of rollback removes.
