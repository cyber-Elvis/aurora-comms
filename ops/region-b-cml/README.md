# Region B — Cisco + Juniper on DevNet CML (config-as-code)

Region B is the Cisco-dominant (+ Juniper) Aurora region, hosted in a **Cisco DevNet
Cisco Modeling Labs (CML) Reservable** sandbox and reached from the local lab over the
**openconnect-in-WSL2 + Docker MASQUERADE** bridge on PC1. It is **ephemeral**: it exists
only during an active reservation and is rebuilt from version-controlled artifacts each
time.

Canonical decision: `docs/adr-002-two-region.md` §3.2. Juniper-in-Region-B: `docs/adr-003-revendor-cisco-region-a.md` §2.3. Reservation discipline / fallbacks: `docs/devnet-resource-strategy.md`. Access/isolation: `docs/adr-004-secure-rings-host-isolation.md`.

## Layout

```
ops/region-b-cml/
├── README.md                         # this file
├── addressing.md                     # proposed Region B IP/AS/RD-RT plan (ratify before deploy)
├── .gitignore                        # keeps live reservation creds out of git
├── topology/
│   └── aurora-region-b.yaml          # CML topology (design intent + import candidate)
└── ansible/
    ├── ansible.cfg
    └── inventory/
        ├── devnet-template.yml       # committed shape (variable names, no secrets)
        └── devnet-current.example.yml# example values; copy to devnet-current.yml (gitignored)
```

The MOP that drives a live bring-up lives at
`ops/access/mops/2026-06-23-region-b-cml-bringup.md`.

## The canonical-topology rule

`topology/aurora-region-b.yaml` is **hand-authored design intent** — the node set, links,
addressing, and day-0 bring-up config per `addressing.md`. CML's exported YAML schema
(`lab.version`) and the exact `node_definition` slugs vary by CML release, so:

1. On the first reservation, **confirm** the controller's schema + node defs:
   `GET /api/v0/node_definitions` (slugs) and an existing lab export (schema version).
2. Import this file. If the controller rejects the schema, lay the topology out in the
   CML UI from this file as the spec, then **export the controller's YAML back over this
   file** and commit it — the exported YAML is guaranteed-valid for that CML version and
   becomes the new canonical.
3. Thereafter, every reservation imports the committed canonical and is identical.

This is why Region B can be "set up in parallel" with Region A: the artifacts are built
and version-controlled locally with **zero contention** for the Dell GNS3 RAM/CPU that
Region A occupies — the compute is Cisco's, only during a reservation.

## Day-0 vs automation split

- **Day-0 (baked into the topology YAML):** hostname, management reachability, SSH, crypto
  keys, loopback0, core interface IPs, IS-IS L2, MPLS LDP. Goal: the fabric boots
  reachable with an LSP-capable core.
- **Service config (pushed via Ansible / config-as-code):** iBGP VPNv4 + RR, PE-CE eBGP,
  VRFs, inter-region eBGP. Mirrors the Region A pattern in `ops/automation-iosxrv/`
  (`cisco.iosxr`) and runs from the WSL Ansible control node against
  `ansible/inventory/devnet-current.yml`.

## What runs where (the hosting principle)

CML is Cisco-native, and the design **deliberately minimises per-reservation BYOI**
(ADR-002 §3.2.4 / §3.1, ADR-003 §2.3). So Region B is split three ways:

| Tier | Where | Nodes |
| --- | --- | --- |
| **Native Cisco in CML** | the reservation | DC-P-R1/R2, MR-PE-R1, MR-PE-R2, HH-PE-R1/R2, MR-CE |
| **BYOI in CML — one only** | the reservation | `JNX-P` vJunos-router (can't run on the nested Dell) |
| **Local + bridged in** | PC1 / Dell | `HH-CE` PA-VM 9.0.4 (PC1 vrnetlab), `JNX-FW` vSRX (Dell), `helix-lan-sw` Aruba CX (local) |

**Only `JNX-P` (vJunos) is a BYOI upload** — and it is unavoidable (the triple-nested Dell
can't boot it). PA-VM, vSRX, and Aruba CX run **locally** and reach the CML Cisco PEs over
the **openconnect-in-WSL2 + Docker MASQUERADE** bridge on PC1; their PE-CE eBGP sessions
ride that bridge (modelled in the topology as `EXT-HELIX-BR` → `EXT-CONN`). This keeps them
available across reservations and avoids the "operationally painful" per-reservation upload.

**Transit, IXP, and RPKI are NOT Region B** — they live in Region A (transits) and PC1
Docker (IXP FRR peers + Routinator). The inter-region A↔B boundary runs as plain eBGP
`64496 ↔ 65002`: the Region A end is `MEL-PE1` (the ASBR), the Region B end is `DC-P-R1`
(the ASBR). Region B's only tie-in is `DC-P-R1` acting as the first IOS-XR ROV enforcer and
IXP attachment over the bridge. See `addressing.md` §8.

### vJunos BYOI upload (the one upload)

Per-reservation: create a `vjunos-router` node definition + upload the qcow2 (CML UI: Tools →
Node/Image Definitions, or `virl2_client`/`cmlutils` to script it). The bring-up boots the
native-Cisco core first; `JNX-P` joins once its image is uploaded. Steps in the MOP.

## Reservation credential capture

When a CML reservation is granted, the DevNet portal shows VPN + lab details. Copy them
into `ansible/inventory/devnet-current.yml` (gitignored). Never commit:

- VPN host / port / username / password (AnyConnect/openconnect endpoint)
- CML controller URL + admin credentials
- Per-node management IPs assigned by the reservation

`devnet-template.yml` and `devnet-current.example.yml` show the expected shape with
placeholder values; only `devnet-current.yml` (real values) is ignored by git.
