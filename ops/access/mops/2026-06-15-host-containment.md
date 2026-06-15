# MOP: Local Host Containment

Date: 2026-06-15

Status: GNS3 VM guard applied; live denial proof still requires running the
lab-node matrix and confirming deny counters/logs.

Scope:

- `MEL-P-CISCO-IOL-RT01` / `10.255.191.11`
- `MEL-PE1-CISCO-IOL-RT01` / `10.255.191.12`
- GNS3 VM `tap-aurora-mgmt` / `10.255.191.1/24`
- PC1 `192.168.200.1`
- PC2/Dell `192.168.200.2`

## Requirement

Lab nodes must not initiate sessions to PC1/PC2 host-admin services:

```text
22,135,139,445,2222,3080,3389,5985,5986,8000,8443,9090,10000
```

The explicit RPKI-RTR exception must remain allowed:

```text
192.168.200.1:3323/tcp
```

## Live Observations

Read-only checks from Codex:

```text
mel-p1 accepted aurora-codex SSH through gns3@100.118.0.46 and returned show clock.
```

From the GNS3 VM:

```text
tap-aurora-mgmt  UNKNOWN  10.255.191.1/24
Connection to 10.255.191.11 22 port [tcp/ssh] succeeded.
Connection to 10.255.191.12 22 port [tcp/ssh] succeeded.
net.ipv4.ip_forward = 1
FORWARD policy ACCEPT
```

No `AURORA-HOST-GUARD` chain was present during the initial check.

Result: the initial demarcation state did not prove host containment. It showed
that IPv4 forwarding was enabled and that the default forward posture was broad
unless a guard chain, node ACL, host firewall, or equivalent policy was applied.

The guard was then applied on the GNS3 VM:

```text
-A FORWARD -i tap-aurora-mgmt -j AURORA-HOST-GUARD
1 ACCEPT tcp to 192.168.200.1 dpt:3323
2 LOG/3 REJECT protected TCP ports to 192.168.200.1
4 LOG/5 REJECT protected TCP ports to 192.168.200.2
6 RETURN
```

Counters were `0` immediately after application because no lab-node denial
matrix had been run yet.

## Changes Staged In Repo

- `ops/access/host-guard/gns3-vm-host-guard.sh`
- `ops/access/host-guard/README.md`
- `ops/access/wazuh/aurora-host-containment-rules.xml`
- `ops/access/wazuh/README.md`
- Updated `ops/access/tailscale-acl.example.hujson`
- Updated MEL node snippets with `NODE-TO-HOSTS` ACL application

## Implementation Steps

1. Apply the GNS3 VM guard:

```bash
sudo sh ./gns3-vm-host-guard.sh apply
sudo sh ./gns3-vm-host-guard.sh status
```

2. Apply or confirm the node ACL on MEL nodes:

```ios
show running-config | section NODE-TO-HOSTS
show ip interface Ethernet0/1 | include access list
```

3. Run the lab-node denial matrix from `ops/access/host-guard/README.md`.

4. Confirm guard counters and logs:

```bash
sudo sh ./gns3-vm-host-guard.sh status
sudo journalctl -k -g AURORA_HOST_GUARD --since -15min
```

5. Confirm Wazuh rules match the sample denied-flow and RPKI exception events:

```bash
sudo /var/ossec/bin/wazuh-logtest
```

## Pass Criteria

- Protected PC1/PC2 services are refused, reset, or timed out from lab nodes.
- PC1 `192.168.200.1:3323` opens only for the RPKI-RTR exception when the
  service is running.
- Denied attempts increment an explicit deny counter.
- Wazuh raises rule `100101`, `100103`, or `100104` for denied lab-node attempts.
- No broad Tailscale ACL rule grants `tag:lab` access to `tag:hosts`.

## Rollback

Remove the GNS3 VM guard:

```bash
sudo sh ./gns3-vm-host-guard.sh remove
```

Remove the IOS node ACL only if it causes an unexpected management issue:

```ios
conf t
interface Ethernet0/1
 no ip access-group NODE-TO-HOSTS out
exit
no ip access-list extended NODE-TO-HOSTS
end
write memory
```
