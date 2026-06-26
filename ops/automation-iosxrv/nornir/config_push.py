#!/usr/bin/env python3
"""Phase 2 Nornir config-PUSH (WRITE) — IOS-XR candidate -> commit, MOP-driven.

  bash nr.sh config_push.py                  DRY-RUN  : load candidate, show diff, DISCARD (no change)
  bash nr.sh config_push.py adl-pe1          DRY-RUN on one node
  bash nr.sh config_push.py --apply adl-pe1  APPLY + commit on one node (canary)
  bash nr.sh config_push.py --apply          APPLY + commit on all nodes
  bash nr.sh config_push.py --rollback       push the reverse + commit (undo)

Worked example: a description on Loopback0. Edit APPLY_CFG/ROLLBACK_CFG for real changes.
"""
import os
import sys

from nornir import InitNornir

APPLY_CFG = ["interface Loopback0", "description NORNIR-PHASE2-CANARY"]
ROLLBACK_CFG = ["interface Loopback0", "no description"]
COMMENT = "CHG-NORNIR-PHASE2"  # commit COMMENT (reusable) — NOT a label; IOS-XR rejects reused commit labels

mode, node = "--check", None
for a in sys.argv[1:]:
    if a.startswith("--"):
        mode = a
    else:
        node = a
cfg = ROLLBACK_CFG if mode == "--rollback" else APPLY_CFG

nr = InitNornir(config_file="config.yaml")
nr.inventory.defaults.password = os.environ["AURORA_XR_PASSWORD"]
target = nr.filter(name=node) if node else nr


def push(task):
    conn = task.host.get_connection("netmiko", task.nornir.config)
    conn.config_mode()
    conn.send_config_set(cfg, exit_config_mode=False)
    candidate = conn.send_command_timing("show configuration")
    if mode in ("--apply", "--rollback"):
        out = conn.send_command_timing(f"commit comment {COMMENT}")
        conn.exit_config_mode()
        verb = "ROLLED BACK" if mode == "--rollback" else "APPLIED"
        low = out.lower()
        if "no configuration changes" in low:
            return f"no-op (already {'rolled back' if mode == '--rollback' else 'applied'})"
        if "fail" in low or "% " in out:
            return "COMMIT ERROR: " + " ".join(out.split())
        return f"{verb} + committed (comment {COMMENT})"
    conn.send_command_timing("abort")  # discard the candidate — guarantees no change
    return "DRY-RUN candidate (discarded):\n" + candidate.strip()


result = target.run(name=f"config-push {mode}", task=push)
print(f"\nconfig-push [{mode}]" + (f"  node={node}" if node else "  (all nodes)"))
for host in sorted(result):
    mr = result[host]
    print(f"\n===== {host} — {'FAILED' if mr.failed else 'ok'} =====")
    print(mr[0].result if not mr.failed else mr[0].exception)
