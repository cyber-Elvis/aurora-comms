# MOP: Region A — Internet-edge transit eBGP config (Stage 2/3/4)

Execution MOP with the actual device configs. Companion to
[`2026-06-24-region-a-transit-edge-deploy.md`](2026-06-24-region-a-transit-edge-deploy.md)
(Stage 0 iBGP mesh + Stage 1 node bring-up — both **verified DONE 2026-06-25**).

## Change record

| Field | Value |
| --- | --- |
| Change ID | `CHG-AURORA-REG-A-TRANSIT-EBGP` |
| Date | 2026-06-25 |
| Operator | Elvis (drives device consoles — types config) |
| Coach / verifier | Claude (read-only verify as `aurora-claude` via `ops/access/xr-show.sh`) |
| Scope | eBGP to Transit-A (`transit-a-csr` AS 64497 ↔ MEL-PE1) + Transit-B (`transit-b-iol` AS 64498 ↔ ADL-PE1); §5.1 policy; §5.1a failover; §5.4 hardening |
| Design refs | `docs/region-a-plan.md` §3.2, §4, §5.1, **§5.1a**, **§5.4**, §6 Wave 3.5 |
| Blast radius | Additive eBGP edge on two PEs. IS-IS/LDP/iBGP unaffected. Outbound advertised to "Internet" is filtered to Aurora PI + customer aggregates only. |
| Rollback | Per-stage, end of doc. Remove neighbor + interface + policies; backbone untouched. |

## Addressing (deployed — from plan §4; loopbacks are the verified deployed values)

| Element | Value |
| --- | --- |
| Aurora AS / Transit-A AS / Transit-B AS | 64496 / 64497 / 64498 |
| Transit-A link (MEL-PE1 `Gi0/0/0/2` ↔ CSR `Gi2`) | `10.255.2.0/30` — PE `.1`, CSR `.2`; v6 `2001:db8:ffff:2::/127` — PE `::`, CSR `::1` |
| Transit-B link (ADL-PE1 `Gi0/0/0/1` ↔ IOL `e0/0`) | `10.255.2.4/30` — PE `.5`, IOL `.6`; v6 `2001:db8:ffff:2::2/127` — PE `::2`, IOL `::3` |
| **Transit mgmt (OOB → MGMT-SW01)** | transit-a-csr `Gi1` = `10.255.191.21/24`; transit-b-iol `e0/1` = `10.255.191.22/24` (mgmt net `10.255.191.0/24`, gw/jump `.1`) |
| Aurora PI (advertised outward) | `203.0.113.0/25` + `2001:db8:aaaa::/48` (originated on MEL-PE1) |
| Customer aggregate (advertised when up) | `203.0.113.128/25` + `2001:db8:bbbb::/48` (not yet originated — in the advertise set ready) |
| Transit-originated "Internet" | `0.0.0.0/0` + `::/0` + 8×/28 from `192.0.2.0/24` + `2001:db8:a::/48` |
| Real IPv4 uplink addendum | `2026-06-27-region-a-transit-real-internet.md` - GNS3 Cloud corrected to VM `eth1`; transit PAT added on CSR `Gi3` / IOL `e0/2` |
| LOCAL_PREF (failover) | Transit-A default **200** (primary) / Transit-B default **100** (backup) |

> **Pre-checks (read-only, coach):** Stage 0 iBGP mesh Established both AFs on all 3 PEs;
> Stage 1 nodes up (CSR on `virtio-net-pci`, IOL-XE 17.15). PE transit interfaces currently
> `Shutdown/unassigned` (MEL-PE1 `Gi0/0/0/2`, ADL-PE1 `Gi0/0/0/1`) — expected.

---

## Stage M — Management bootstrap (secure SSH, do FIRST on each transit)

**Why first:** a deployed node's first step is reachable, *authenticated* management. The
transits boot blank/console-only, so the path is: connect to the **telnet console once**
(PC3 Termius → `100.118.0.46:5009` transit-a / `:5013` transit-b — the only way into a node
with no SSH yet), configure secure SSH below, then switch to the **SSH jump path** for all
subsequent access:

```
PC3 Termius --ssh--> gns3@100.118.0.46 --ssh--> labadmin@10.255.191.21   (transit-a-csr)
                                        \--ssh--> labadmin@10.255.191.22   (transit-b-iol)
```

After SSH is up, stop using the telnet console — treat it as break-glass only.

### M.1 — transit-a-csr (console 5009) — operator types
```
configure terminal
hostname transit-a-csr
ip domain name aurora.lab
!
interface GigabitEthernet1
 description MGMT to MGMT-SW01 (OOB management)
 ip address 10.255.191.21 255.255.255.0
 no shutdown
exit
!
aaa new-model
aaa authentication login default local
aaa authorization exec default local
username labadmin privilege 15 secret <STRONG-RANDOM-PW>     ! store in vault; not personal
!
crypto key generate rsa modulus 2048
ip ssh version 2
ip ssh time-out 60
ip ssh authentication-retries 3
!
ip access-list standard MGMT-SSH
 permit 10.255.191.0 0.0.0.255
 deny   any log
!
line vty 0 4
 transport input ssh
 access-class MGMT-SSH in
 exec-timeout 15 0
 login authentication default
!
line con 0
 exec-timeout 15 0
end
write memory
```

### M.2 — transit-b-iol (console 5013) — operator types
Identical, but the MGMT-SW01-facing interface is **Ethernet0/1** and the IP is **.22**:
```
configure terminal
hostname transit-b-iol
ip domain name aurora.lab
!
interface Ethernet0/1
 description MGMT to MGMT-SW01 (OOB management)
 ip address 10.255.191.22 255.255.255.0
 no shutdown
exit
!
aaa new-model
aaa authentication login default local
aaa authorization exec default local
username labadmin privilege 15 secret <STRONG-RANDOM-PW>
!
crypto key generate rsa modulus 2048
ip ssh version 2
ip ssh time-out 60
ip ssh authentication-retries 3
!
ip access-list standard MGMT-SSH
 permit 10.255.191.0 0.0.0.255
 deny   any log
!
line vty 0 4
 transport input ssh
 access-class MGMT-SSH in
 exec-timeout 15 0
 login authentication default
end
write memory
```

### M.3 — Verify (coach, read-only via the jump)
- From the GNS3 jump: `ssh labadmin@10.255.191.21` / `.22` connects (SSHv2 password prompt).
- On the node: `show ip ssh` → v2 enabled; `show run | include transport input` → `ssh` only (telnet to vty refused); `ping 10.255.191.1` (mgmt gw/jump) succeeds.

**Notes / hardening:**
- `transport input ssh` + `access-class MGMT-SSH` = SSH only, and only from the mgmt subnet.
  The GNS3 **console** telnet is separate and unavoidable for the one-time bootstrap — break-glass after.
- Mgmt is in the **global table** here (matches the XR `MgmtEth` convention). Gold standard =
  a dedicated **management VRF** (`vrf forwarding Mgmt-intf` + in-VRF `ip ssh`) to fully isolate
  mgmt from the eBGP data plane — optional follow-up.
- IOS-XE supports **SSH public-key** auth (`ip ssh pubkey-chain`) — password is the baseline to
  match the lab; pubkey is a later hardening (mirrors the parked XR key goal).
- `labadmin` = dedicated break-glass admin (random pw, stored in the vault, not personal). Scoped
  automation/read-only accounts can follow later, mirroring the XR RBAC tiers.

---

## Automation readiness (management transports)

Scaffolds: `ops/automation-iosxe/` (Ansible tree + `nornir/`). Secret:
`vault_transit_labadmin_password` (vault-id `labadmin`, `~/.aurora-vault-pass`).

| Transport | transit-a (CSR1000v 16.8.1a) | transit-b (IOL-XE 17.15.1) |
| --- | --- | --- |
| SSH CLI — Ansible (`cisco.ios` / `network_cli`) | ✅ verified | ✅ verified |
| SSH CLI — Nornir / Netmiko | ✅ verified | ✅ verified |
| NETCONF (`:830`, `netconf-yang`) | ❌ `:830` won't bind; `netconf-yang` toggle tried → no change (box can't gen persistent self-signed cert) | ❌ unsupported (no YANG infra) |
| RESTCONF (`:443`, `restconf`) | ❌ no usable HTTPS cert (`show crypto pki cert` EMPTY); persistent self-signed cert gen fails even with authoritative clock (`ntp master`); OpenSSL 1.1.1 **and** 3.5 both alert-40 → PKI/NVRAM defect | ❌ unsupported |
| gNMI | ❌ Cat 9300/9400/9500-only on 16.8 (not CSR1000v) | ❌ absent |

> **FINAL verdict (2026-06-27, deep-research-confirmed + tested):** NETCONF/RESTCONF/gNMI are a **dead end on these images**. Every documented workaround was tried and failed on transit-a — client OpenSSL (1.1.1 *and* 3.5, via a Docker `curlimages/curl:7.78.0`), `netconf-yang` toggle, HTTPS cert regen, and an authoritative clock (`ntp master`). Root causes: gNMI is platform-gated to Catalyst 9k on 16.8; NETCONF `:830` never binds; RESTCONF has no usable HTTPS cert (CSR can't generate a persistent self-signed cert — PKI/NVRAM defect). **Working automation tier = CLI (Ansible + Nornir); programmatic transports → DevNet CML / IOS-XE 17.x (Cat8000V).** Same conclusion as the XRv 6.1.3 gNMI gap.

Probe (read-only, 2026-06-27): `show platform software yang-management process` lists the CSR's YANG
daemons (`confd/nesd/ncsshd/...`, `nginx` Running, `ip http secure-server` already on) but is
`% Invalid input` on the IOL; `show gnmi-yang state` is `% Invalid input` on both. **NETCONF/RESTCONF are
CSR-only; the IOL is CLI/SSH-only; gNMI needs a 17.x/CML image** (mirrors the XRv 6.1.3 gNMI gap).

**Ansible needs `export ANSIBLE_CONFIG=$PWD/ansible.cfg`** — `/mnt/d` is world-writable, so the in-dir
`ansible.cfg` (and its `vault_password_file`) is otherwise ignored. Ansible uses **libssh** (paramiko
ignores the ProxyJump and times out); Nornir/Netmiko uses an `ssh_config` ProxyCommand with `use_keys:false`.

Run the proven CLI automation:
```bash
cd ops/automation-iosxe && export ANSIBLE_CONFIG=$PWD/ansible.cfg
ansible-playbook playbooks/verify-platform.yml          # both nodes
cd nornir && bash nr.sh conntest.py 10.255.191.21       # Nornir/Netmiko smoke test
```

Enable NETCONF + RESTCONF (**transit-a only**, operator types on console 5009):
```
conf t
aaa authorization exec default local   ! NETCONF/RESTCONF authorize via AAA
netconf-yang
restconf
end
write memory
```
**Smoke-test outcome (2026-06-27)** — scaffolds added (`ops/automation-iosxe/netconf/` = ncclient
through a bastion `:830` forward; `restconf/` = curl through a `:443` forward), but BOTH are blocked
by the **CSR 16.8.1a image age**, not the tooling:
- **NETCONF** — `netconf-yang` is configured and `show netconf-yang sessions` works, but **`:830`
  never enters LISTEN** (`show tcp brief all` shows only `:22/:80/:443`); `ncsshd` shows "Running"
  with no listener. RSA host key is 2048-bit and `:22` SSH is fine, so it's not key size — a 16.8 quirk.
- **RESTCONF** — `:443` listens and advertises TLS 1.2 + GCM ciphers, but the handshake **fails from
  WSL OpenSSL 3.x** even capped at TLS 1.2 with the exact GCM ciphers + `@SECLEVEL=0` (alert 40); the
  2018 self-signed cert / TLS stack is incompatible with modern OpenSSL.

So on these images the **working automation tier is CLI (Ansible + Nornir)**; NETCONF/RESTCONF/gNMI
need **IOS-XE 17.x / DevNet CML** (same conclusion as the XRv 6.1.3 gNMI gap). The scaffolds are kept
under `ops/automation-iosxe/{netconf,restconf}/` — they're correct and will work against a 17.x image.

---

## Stage 2A — Transit-A end to end (`transit-a-csr` ↔ MEL-PE1)

### 2A.1 — transit-a-csr (CSR1000v, IOS-XE, AS 64497) — operator types on console 5009

Blank CSR: at the `[yes/no]` setup dialog answer **no**, press RETURN, then `enable`.

```
configure terminal
hostname transit-a-csr
no ip domain lookup
!
interface GigabitEthernet2
 description to-MEL-PE1 Gi0/0/0/2 (Aurora AS64496) TRANSIT-A
 ip address 10.255.2.2 255.255.255.252
 ipv6 address 2001:DB8:FFFF:2::1/127
 no shutdown
exit
!
! prefixes this simulated transit originates -> pin to Null0 so network stmts resolve
ip route 0.0.0.0 0.0.0.0 Null0
ip route 192.0.2.0   255.255.255.240 Null0
ip route 192.0.2.16  255.255.255.240 Null0
ip route 192.0.2.32  255.255.255.240 Null0
ip route 192.0.2.48  255.255.255.240 Null0
ip route 192.0.2.64  255.255.255.240 Null0
ip route 192.0.2.80  255.255.255.240 Null0
ip route 192.0.2.96  255.255.255.240 Null0
ip route 192.0.2.112 255.255.255.240 Null0
ipv6 route ::/0 Null0
ipv6 route 2001:DB8:A::/48 Null0
!
router bgp 64497
 bgp router-id 10.255.2.2
 bgp log-neighbor-changes
 no bgp default ipv4-unicast
 neighbor 10.255.2.1 remote-as 64496
 neighbor 2001:DB8:FFFF:2:: remote-as 64496
 !
 address-family ipv4 unicast
  network 0.0.0.0 mask 0.0.0.0
  network 192.0.2.0   mask 255.255.255.240
  network 192.0.2.16  mask 255.255.255.240
  network 192.0.2.32  mask 255.255.255.240
  network 192.0.2.48  mask 255.255.255.240
  network 192.0.2.64  mask 255.255.255.240
  network 192.0.2.80  mask 255.255.255.240
  network 192.0.2.96  mask 255.255.255.240
  network 192.0.2.112 mask 255.255.255.240
  neighbor 10.255.2.1 activate
 exit-address-family
 !
 address-family ipv6 unicast
  network ::/0
  network 2001:DB8:A::/48
  neighbor 2001:DB8:FFFF:2:: activate
 exit-address-family
end
write memory
```

### 2A.2 — MEL-PE1 (IOS-XR, AS 64496) — operator types; two-stage commit

```
configure
!
interface GigabitEthernet0/0/0/2
 description to-transit-a-csr eBGP AS64497 TRANSIT-A
 ipv4 address 10.255.2.1 255.255.255.252
 ipv6 address 2001:db8:ffff:2::/127
 no shutdown
!
! ---- inbound bogon/martian guard (v4 + v6) ----
prefix-set BOGON-V4
  0.0.0.0/8 le 32, 10.0.0.0/8 le 32, 100.64.0.0/10 le 32, 127.0.0.0/8 le 32,
  169.254.0.0/16 le 32, 172.16.0.0/12 le 32, 192.168.0.0/16 le 32,
  198.18.0.0/15 le 32, 224.0.0.0/4 le 32, 240.0.0.0/4 le 32
end-set
!
prefix-set BOGON-V6
  ::/8 le 128, 100::/64 le 128, 2001:db8::/32 ge 49 le 128, fc00::/7 le 128, fe80::/10 le 128
end-set
!
! ---- what Aurora advertises OUTWARD (PI + customer aggregate ONLY) ----
prefix-set AURORA-ADV-V4
  203.0.113.0/25, 203.0.113.128/25
end-set
!
prefix-set AURORA-ADV-V6
  2001:db8:aaaa::/48, 2001:db8:bbbb::/48
end-set
!
! ---- policies: TRANSIT-A primary (LP 200) ----
route-policy TRANSIT-A-IN-V4
  if destination in BOGON-V4 then
    drop
  endif
  if destination in (0.0.0.0/0) then
    set local-preference 200
  endif
  pass
end-policy
!
route-policy TRANSIT-A-IN-V6
  if destination in BOGON-V6 then
    drop
  endif
  if destination in (::/0) then
    set local-preference 200
  endif
  pass
end-policy
!
route-policy TRANSIT-OUT-V4
  if destination in AURORA-ADV-V4 then
    pass
  else
    drop
  endif
end-policy
!
route-policy TRANSIT-OUT-V6
  if destination in AURORA-ADV-V6 then
    pass
  else
    drop
  endif
end-policy
!
! ---- originate Aurora PI so there is something to advertise outward ----
router static
 address-family ipv4 unicast
  203.0.113.0/25 Null0
 address-family ipv6 unicast
  2001:db8:aaaa::/48 Null0
!
router bgp 64496
 address-family ipv4 unicast
  network 203.0.113.0/25
 !
 address-family ipv6 unicast
  network 2001:db8:aaaa::/48
 !
 neighbor 10.255.2.2
  remote-as 64497
  description eBGP-TRANSIT-A
  address-family ipv4 unicast
   route-policy TRANSIT-A-IN-V4 in
   route-policy TRANSIT-OUT-V4 out
   maximum-prefix 1000 75
  !
 !
 neighbor 2001:db8:ffff:2::1
  remote-as 64497
  description eBGP-TRANSIT-A-v6
  address-family ipv6 unicast
   route-policy TRANSIT-A-IN-V6 in
   route-policy TRANSIT-OUT-V6 out
   maximum-prefix 200 75
  !
 !
!
show configuration
commit
end
```

### 2A.3 — Verify (coach, read-only)

- MEL-PE1: `show bgp ipv4 unicast summary` → 10.255.2.2 **Established**, PfxRcd ≈ 9 (default + 8 mock).
- MEL-PE1: `show bgp ipv4 unicast 0.0.0.0/0` → from 64497, **local-pref 200**, best.
- MEL-PE1: `show route 0.0.0.0/0` → via 10.255.2.2.
- GEL-PE1 / ADL-PE1: `show bgp ipv4 unicast 0.0.0.0/0` → learned via iBGP, next-hop `10.0.0.2`, LP 200 (proves §5.1a + next-hop-self).
- transit-a-csr: `show ip bgp summary` → 10.255.2.1 Established; `show bgp ipv4 unicast neighbors 10.255.2.1 routes` → only `203.0.113.0/25` (+128/25 when customer up) received (proves outbound no-leak).

---

## Stage 2B — Transit-B end to end (`transit-b-iol` ↔ ADL-PE1)

### 2B.1 — transit-b-iol (IOL-XE 17.15, IOS-XE, AS 64498) — operator types on console 5013

> This node already has a startup-config — run `show running-config` first and reconcile;
> the block below is additive. Interface is `Ethernet0/0`.

```
configure terminal
hostname transit-b-iol
no ip domain lookup
!
interface Ethernet0/0
 description to-ADL-PE1 Gi0/0/0/1 (Aurora AS64496) TRANSIT-B
 ip address 10.255.2.6 255.255.255.252
 ipv6 address 2001:DB8:FFFF:2::3/127
 no shutdown
exit
!
ip route 0.0.0.0 0.0.0.0 Null0
ip route 192.0.2.0   255.255.255.240 Null0
ip route 192.0.2.16  255.255.255.240 Null0
ip route 192.0.2.32  255.255.255.240 Null0
ip route 192.0.2.48  255.255.255.240 Null0
ip route 192.0.2.64  255.255.255.240 Null0
ip route 192.0.2.80  255.255.255.240 Null0
ip route 192.0.2.96  255.255.255.240 Null0
ip route 192.0.2.112 255.255.255.240 Null0
ipv6 route ::/0 Null0
ipv6 route 2001:DB8:A::/48 Null0
!
router bgp 64498
 bgp router-id 10.255.2.6
 bgp log-neighbor-changes
 no bgp default ipv4-unicast
 neighbor 10.255.2.5 remote-as 64496
 neighbor 2001:DB8:FFFF:2::2 remote-as 64496
 !
 address-family ipv4 unicast
  network 0.0.0.0 mask 0.0.0.0
  network 192.0.2.0   mask 255.255.255.240
  network 192.0.2.16  mask 255.255.255.240
  network 192.0.2.32  mask 255.255.255.240
  network 192.0.2.48  mask 255.255.255.240
  network 192.0.2.64  mask 255.255.255.240
  network 192.0.2.80  mask 255.255.255.240
  network 192.0.2.96  mask 255.255.255.240
  network 192.0.2.112 mask 255.255.255.240
  neighbor 10.255.2.5 activate
 exit-address-family
 !
 address-family ipv6 unicast
  network ::/0
  network 2001:DB8:A::/48
  neighbor 2001:DB8:FFFF:2::2 activate
 exit-address-family
end
write memory
```

### 2B.2 — ADL-PE1 (IOS-XR, AS 64496) — operator types; two-stage commit

> Identical structure to MEL-PE1 but **LP 100** (backup) and it does NOT originate the PI —
> it re-advertises the iBGP-learned PI outward (proves iBGP→eBGP). BOGON/AURORA-ADV prefix-sets
> + TRANSIT-OUT policies are the same; if you prefer, define them once per box (they are
> node-local, so they must exist on ADL too — included here).

```
configure
!
interface GigabitEthernet0/0/0/1
 description to-transit-b-iol eBGP AS64498 TRANSIT-B
 ipv4 address 10.255.2.5 255.255.255.252
 ipv6 address 2001:db8:ffff:2::2/127
 no shutdown
!
prefix-set BOGON-V4
  0.0.0.0/8 le 32, 10.0.0.0/8 le 32, 100.64.0.0/10 le 32, 127.0.0.0/8 le 32,
  169.254.0.0/16 le 32, 172.16.0.0/12 le 32, 192.168.0.0/16 le 32,
  198.18.0.0/15 le 32, 224.0.0.0/4 le 32, 240.0.0.0/4 le 32
end-set
!
prefix-set BOGON-V6
  ::/8 le 128, 100::/64 le 128, 2001:db8::/32 ge 49 le 128, fc00::/7 le 128, fe80::/10 le 128
end-set
!
prefix-set AURORA-ADV-V4
  203.0.113.0/25, 203.0.113.128/25
end-set
!
prefix-set AURORA-ADV-V6
  2001:db8:aaaa::/48, 2001:db8:bbbb::/48
end-set
!
route-policy TRANSIT-B-IN-V4
  if destination in BOGON-V4 then
    drop
  endif
  if destination in (0.0.0.0/0) then
    set local-preference 100
  endif
  pass
end-policy
!
route-policy TRANSIT-B-IN-V6
  if destination in BOGON-V6 then
    drop
  endif
  if destination in (::/0) then
    set local-preference 100
  endif
  pass
end-policy
!
route-policy TRANSIT-OUT-V4
  if destination in AURORA-ADV-V4 then
    pass
  else
    drop
  endif
end-policy
!
route-policy TRANSIT-OUT-V6
  if destination in AURORA-ADV-V6 then
    pass
  else
    drop
  endif
end-policy
!
router bgp 64496
 neighbor 10.255.2.6
  remote-as 64498
  description eBGP-TRANSIT-B
  address-family ipv4 unicast
   route-policy TRANSIT-B-IN-V4 in
   route-policy TRANSIT-OUT-V4 out
   maximum-prefix 1000 75
  !
 !
 neighbor 2001:db8:ffff:2::3
  remote-as 64498
  description eBGP-TRANSIT-B-v6
  address-family ipv6 unicast
   route-policy TRANSIT-B-IN-V6 in
   route-policy TRANSIT-OUT-V6 out
   maximum-prefix 200 75
  !
 !
!
show configuration
commit
end
```

### 2B.3 — Verify (coach, read-only)

- ADL-PE1: `show bgp ipv4 unicast summary` → 10.255.2.6 Established; `show bgp ipv4 unicast 0.0.0.0/0` → from 64498, **LP 100**.
- transit-b-iol: `show bgp ipv4 unicast neighbors 10.255.2.5 routes` → only `203.0.113.0/25` (no-leak holds via the iBGP-learned PI).

---

## Stage 3 — transit-edge hardening (§5.4) — per session, after 2A/2B are Established

`maximum-prefix` and `log-neighbor-changes` are already in Stage 2. Add fast failover +
spoof/patch resilience. **Apply BFD + graceful-restart now; the items flagged ⚠ need their
6.1.3 syntax confirmed with `?` before commit (XR command availability drifts by release —
same lesson as the netconf-yang enable).**

### 3.1 — BFD fast failover (both ends of each session)

PE side (IOS-XR, e.g. MEL-PE1):
```
configure
router bgp 64496
 neighbor 10.255.2.2
  bfd fast-detect
  bfd minimum-interval 300
  bfd multiplier 3
 !
!
commit
```
Transit side (IOS-XE):
```
configure terminal
interface GigabitEthernet2
 bfd interval 300 min_rx 300 multiplier 3
exit
router bgp 64497
 neighbor 10.255.2.1 fall-over bfd
end
```

### 3.2 — Graceful restart (patch resilience, §8.8)

IOS-XR: `router bgp 64496` → `bgp graceful-restart` (instance-wide; resets sessions — do in a
window). IOS-XE: `router bgp 64497` → `bgp graceful-restart`.

### 3.3 — ⚠ Verify-then-apply on 6.1.3 (do NOT paste blind)

| Control | Intended | Confirm first |
| --- | --- | --- |
| **GTSM** | drop spoofed multi-hop (`ttl-security`) | IOS-XR 6.1.3 may not support BGP `ttl-security`; check `neighbor 10.255.2.2 ?`. If absent, defer to image upgrade. IOS-XE side: `neighbor 10.255.2.1 ttl-security hops 1`. |
| **TCP-AO** | anti-session-hijack auth | needs a `key chain` + `neighbor … ao <chain>`; `aurora-security` crypto role / labadmin. Confirm `key chain` keyword on 6.1.3. MD5 (`password`) is the fallback. |
| **RPKI ROV** | drop invalid (§5.2 Phase C1) | requires Routinator RTR at `192.168.137.1:3323` (Phase C, not yet up). Add `rpki server` + a `validation-state is invalid → drop` policy when the validator is live. |

---

## Stage 4 — verify + failover (coach, read-only)

1. **Dual-default present (proves §5.1a):** on MEL-PE1 `show bgp ipv4 unicast 0.0.0.0/0` shows
   **two** paths — Transit-A direct (LP 200, best) and Transit-B via iBGP from `10.0.0.4` (LP 100).
2. **Best-path:** every PE's `show route 0.0.0.0/0` resolves to Transit-A (LP 200) — MEL-PE1
   direct, GEL/ADL via LDP to `10.0.0.2`.
3. **Failover:** operator `shutdown` MEL-PE1 `Gi0/0/0/2` (or the CSR) → within BFD (<1s) every
   PE's default reconverges to **Transit-B (LP 100) via ADL-PE1** (`show route 0.0.0.0/0` →
   next-hop `10.0.0.4`). `no shutdown` → flips back to Transit-A.
4. **No-leak outbound:** each transit receives only `203.0.113.0/25` (+ customer /25 when up).
5. Capture evidence → `ops/access/evidence/2026-06-25-region-a-transit-edge.md`.

---

## Rollback

- **Transit eBGP (per PE, IOS-XR):** `configure` → `no router bgp 64496 neighbor 10.255.2.2`
  (and the v6 neighbor) → `no interface GigabitEthernet0/0/0/2` addressing (or `shutdown`) →
  `commit`. Policies/prefix-sets can stay (inert) or `no route-policy …` / `no prefix-set …`.
- **Transit node (IOS-XE):** `no router bgp <asn>` → `write memory` (or stop the node via GNS3).
- **PI origination:** `no network 203.0.113.0/25` under `router bgp` + `no 203.0.113.0/25 Null0`
  under `router static` on MEL-PE1.
- Backbone IS-IS/LDP/iBGP are untouched throughout — nothing to roll back there.
