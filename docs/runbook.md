# Aurora Communications — Operational Runbook

> **Scope note (ADR-003 v1.2 / ADR-004 v1.0, 2026-06-14).** The commands below are the **W1 containerlab/FRR baseline** (`clab-aurora-*`, `vtysh`). The **built Region A is now a Cisco GNS3 core** mapped to the Melbourne/Sydney/Brisbane/Geelong/Adelaide/Perth/Darwin/Tasmania POP overlay — for current Region A operations use `region-a-plan.md` §6 (bring-up waves), §7 (per-node smoke tests, IOS/IOS-XR `show` commands), and §8 (ops + MOP shape). For secure SSH/access workflows use `ops/access/` and validate the ADR-004 host-isolation controls. A region-specific runbook split (Region A GNS3 + Region B CML) is a pending follow-up.

## 1. Quick health check

Run after any deploy or change. All four checks should succeed.

    sudo containerlab inspect -t ~/aurora-comms/lab/backbone/topology.clab.yml
    sudo docker exec clab-aurora-melbourne vtysh -c "show isis neighbor"
    sudo docker exec clab-aurora-melbourne vtysh -c "show ip bgp summary"
    for lo in 10.0.0.2 10.0.0.3 10.0.0.4; do
      sudo docker exec clab-aurora-melbourne ping -c 2 -W 2 $lo | tail -1
    done

Expected results:
- 4 nodes running, all `running` state.
- 3 IS-IS adjacencies on each PE, all `Up`.
- 3 iBGP peers per PE, all `Established`, `PfxRcd 1`.
- All loopback pings 0% loss.

## 2. Diagnostic commands by protocol

### IS-IS

    show isis neighbor
    show isis neighbor detail
    show isis database
    show isis database detail
    show isis topology level-2
    show isis interface
    show isis summary

### MPLS LDP

    show mpls ldp neighbor
    show mpls ldp binding
    show mpls table
    show mpls interface

### BGP

    show ip bgp summary
    show ip bgp
    show ip bgp neighbors 10.0.0.2
    show ip bgp neighbors 10.0.0.2 advertised
    show ip bgp neighbors 10.0.0.2 received

### Forwarding plane

    show ip route
    show ip route 10.0.0.2
    show ip route isis
    show ip route bgp

## 3. Container access

    # Shell into a router
    sudo docker exec -it clab-aurora-<router> bash

    # Drop directly into FRR's CLI
    sudo docker exec -it clab-aurora-<router> vtysh

    # Inside vtysh, enter configure mode
    configure terminal

    # Tail FRR logs
    sudo docker exec clab-aurora-<router> tail -f /var/log/frr/frr.log

## 4. Standard procedures

### 4.1 Deploy from scratch

    cd ~/aurora-comms/lab/backbone
    sudo containerlab deploy -t topology.clab.yml
    sleep 45
    # run health check (section 1)

### 4.2 Apply a config change

    vim ~/aurora-comms/lab/backbone/<router>/frr.conf
    cd ~/aurora-comms/lab/backbone
    sudo containerlab destroy -t topology.clab.yml --cleanup
    sudo containerlab deploy -t topology.clab.yml
    sleep 45
    # run health check

(After Ansible lands: `make redeploy` from `lab/automation/`.)

### 4.3 Tear down

    cd ~/aurora-comms/lab/backbone
    sudo containerlab destroy -t topology.clab.yml --cleanup

### 4.4 Add a new POP

1. Edit `lab/backbone/topology.clab.yml`: add the new node + its links.
2. Create `lab/backbone/<newpop>/{daemons,frr.conf,vtysh.conf}` (copy from existing PE; adjust IPs and NET).
3. Update each existing PE's `frr.conf`: add the iBGP neighbour for the new PE (until W2 RR migration removes this step).
4. Update the region-specific plan first (`docs/region-a-plan.md` §4 for Region A), then mirror any cross-region summary changes into `docs/ip-plan.md`.
5. Redeploy.

## 5. Known issues

### 5.1 LDP sessions establish but no labels (WSL2)

**Symptom:** `show mpls ldp neighbor` reports active sessions; `show mpls table` is empty or sparse.

**Cause:** WSL2's default kernel does not have MPLS modules (`mpls_router`, `mpls_iptunnel`) loaded.

**Workaround:** IS-IS + BGP work normally; MPLS forwarding is degraded. Proper fix: move containerlab to a Hyper-V Linux VM where MPLS works out of the box, or rebuild the WSL2 kernel with MPLS support.

**Status:** Known and accepted for W1.

### 5.2 IS-IS adjacencies don't form

**Symptom:** `show isis neighbor` empty after 60+ seconds.

**Cause:** Bind-mount mismatch — `frr.conf` in the container differs from what is expected.

**Diagnostic:**

    sudo docker exec clab-aurora-<router> cat /etc/frr/frr.conf | grep "router isis"
    sudo docker exec clab-aurora-<router> cat /etc/frr/daemons | grep isisd

**Fix:** Confirm `daemons` has `isisd=yes`, confirm `frr.conf` has the IS-IS router stanza, redeploy.

### 5.3 BGP sessions stuck in `Active`

**Symptom:** `show ip bgp summary` shows peer state `Active` (not `Established`).

**Cause:** TCP cannot reach peer's loopback.

**Diagnostic:**

    sudo docker exec clab-aurora-<source> ping -c 2 <peer-loopback>

**Fix:** If ping fails, IS-IS hasn't converged — wait longer or check IS-IS adjacencies. If ping works but BGP doesn't establish, verify `update-source lo` is set on the BGP neighbour.

## 6. Escalation

Lab issues escalate to:
1. Engineering owner.
2. Containerlab GitHub issues for tool-specific bugs.
3. FRR mailing list for protocol-specific issues.

Production Aurora (if real) would have a defined NOC + on-call rotation, ticketing, and PagerDuty integration. Out of scope for the lab.
