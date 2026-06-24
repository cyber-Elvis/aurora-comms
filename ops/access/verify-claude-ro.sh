#!/usr/bin/env bash
# Coach verification (read-only): confirm the aurora-claude agent account logs in
# across the Region A IOS-XRv fleet and that `aaa authorization exec default local`
# is present on every node (the NETCONF/gRPC task-RBAC-bypass hardening, Cisco
# advisory cisco-sa-iosxr-info-GXp7nVcP).
#
# Read-only by construction: aurora-claude has no `task write` (xr-ssh.py also
# enforces a show/ping/traceroute/debug allowlist). The vault password is fed to
# the reader over STDIN, never on argv, so it is not exposed in the VM process list.
#
# Run from the WSL control node (decrypts the vault locally, hops the GNS3 bastion):
#   bash ops/access/verify-claude-ro.sh
set -uo pipefail
ANSIBLE_PY=/home/fourty3/.local/share/pipx/venvs/ansible-core/bin/python
REPO=/mnt/d/CyberLab/Repos/aurora-comms
V="$REPO/ops/automation-iosxrv/group_vars/region_a_iosxr_claude/vault.yml"
BAST=gns3@100.118.0.46

# Ship the current reader to the VM so STDIN password mode is guaranteed present.
scp -q -o StrictHostKeyChecking=accept-new "$REPO/ops/access/xr-ssh.py" "$BAST:/home/gns3/xr-ssh.py"

PASS=$("$ANSIBLE_PY" - "$V" <<'PYEOF'
import sys, re
from pathlib import Path
from ansible.parsing.vault import VaultLib, VaultSecret
s = VaultSecret((Path.home()/".aurora-vault-pass").read_bytes().strip())
v = VaultLib([("default", s)])
txt = v.decrypt(Path(sys.argv[1]).read_bytes()).decode()
m = re.search(r':\s*"([^"]*)"', txt) or re.search(r':\s*(\S+)', txt)
sys.stdout.write(m.group(1))
PYEOF
)
[ -n "$PASS" ] || { echo "FATAL: could not decrypt aurora-claude password"; exit 1; }

# gel-pe1 .15, mel-pe1 .12, mel-p1 .11 = rolled 2026-06-24; adl-pe1 .17 = baseline.
for HOST in 10.255.191.15 10.255.191.12 10.255.191.11 10.255.191.17; do
  echo "============================================================"
  echo "NODE $HOST   login=aurora-claude (read-only)"
  echo "============================================================"
  printf '%s\nshow running-config aaa authorization\nshow user tasks\n' "$PASS" \
    | ssh -o StrictHostKeyChecking=accept-new "$BAST" \
        "AURORA_XR_PASSWORD_STDIN=1 python3 /home/gns3/xr-ssh.py $HOST aurora-claude" \
    || echo ">>> RESULT: connection/auth FAILED for $HOST (rollout gap?)"
  sleep 3
done
