#!/usr/bin/env bash
# Fast read-only IOS-XR show runner as the aurora-claude agent account.
#
# Why this is fast: the aurora-claude password lives encrypted in the Ansible
# vault (correct at-rest hygiene), but importing `ansible` just to decrypt it
# costs ~5-8s. We pay that ONCE per session — the cleartext is cached in RAM
# (/dev/shm, mode 600, never on disk) and an SSH ControlMaster to the bastion is
# reused — so each subsequent call is ~1-2s, no Ansible, no re-auth, no re-scp.
#
#   bash xr-show.sh <node-ip> ["show ..."] ["show ..."] ...
#   bash xr-show.sh 10.255.191.12 "show bgp ipv4 unicast summary" "show bgp vpnv4 unicast summary"
#
# Read-only by construction: aurora-claude has no `task write`, and xr-ssh.py
# enforces a show/ping/traceroute/debug allowlist. Purge the cache with:
#   rm -f /dev/shm/.aurora-claude-pw; ssh -S /dev/shm/.aurora-bast-ctl -O exit gns3@100.118.0.46
set -uo pipefail
REPO=/mnt/d/CyberLab/Repos/aurora-comms
BAST=gns3@100.118.0.46
CACHE=/dev/shm/.aurora-claude-pw
CTL=/dev/shm/.aurora-bast-ctl

NODE="${1:?usage: xr-show.sh <node-ip> [show-cmd ...]}"; shift
[ "$#" -ge 1 ] || set -- "show bgp ipv4 unicast summary"

# 1) password — decrypt once, then cache in RAM (paid only on a cold session)
if [ ! -s "$CACHE" ]; then
  ANSIBLE_PY=/home/fourty3/.local/share/pipx/venvs/ansible-core/bin/python
  V="$REPO/ops/automation-iosxrv/group_vars/region_a_iosxr_claude/vault.yml"
  ( umask 077; "$ANSIBLE_PY" - "$V" > "$CACHE" ) <<'PYEOF'
import sys, re
from pathlib import Path
from ansible.parsing.vault import VaultLib, VaultSecret
s = VaultSecret((Path.home()/".aurora-vault-pass").read_bytes().strip())
v = VaultLib([("default", s)])
txt = v.decrypt(Path(sys.argv[1]).read_bytes()).decode()
m = re.search(r':\s*"([^"]*)"', txt) or re.search(r':\s*(\S+)', txt)
sys.stdout.write(m.group(1))
PYEOF
fi
[ -s "$CACHE" ] || { echo "FATAL: vault decrypt failed"; exit 1; }

# 2) bastion ControlMaster — open once, reuse the auth/TCP, scp the reader once
if ! ssh -S "$CTL" -O check "$BAST" 2>/dev/null; then
  ssh -M -S "$CTL" -o ControlPersist=600 -f -N -o StrictHostKeyChecking=accept-new "$BAST"
  scp -q -o ControlPath="$CTL" "$REPO/ops/access/xr-ssh.py" "$BAST:/home/gns3/xr-ssh.py"
fi

# 3) run the shows over the shared connection (password on stdin, never argv)
printf '%s\n' "$(cat "$CACHE")" "$@" \
  | ssh -S "$CTL" "$BAST" "AURORA_XR_PASSWORD_STDIN=1 python3 /home/gns3/xr-ssh.py $NODE aurora-claude"
