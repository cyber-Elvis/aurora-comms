#!/usr/bin/env bash
# NETCONF runner for the IOS-XE transit nodes: decrypt labadmin from the vault, open a
# bastion TCP forward to a node's :830, run an ncclient script against 127.0.0.1:8830,
# then tear the forward down.
#   bash nc.sh nc_caps.py                  -> list NETCONF capabilities (smoke test)
#   bash nc.sh nc_get.py                   -> get-config hostname (read smoke test)
#   NC_NODE=10.255.191.21 bash nc.sh ...   -> target a node (default transit-a .21)
# NOTE: transit-b (IOL) has NO NETCONF agent — CSR transit-a (.21) only.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ANSIBLE_PY=/home/fourty3/.local/share/pipx/venvs/ansible-core/bin/python
NETPY="$HOME/netconf-lab/venv/bin/python"
VAULT=/mnt/d/CyberLab/Repos/aurora-comms/ops/automation-iosxe/group_vars/transit/vault.yml
BAST=gns3@100.118.0.46
NODE="${NC_NODE:-10.255.191.21}"
echo "==> NETCONF target ${NODE}:830 (via ${BAST})" >&2

SCRIPT="${1:?usage: bash nc.sh <script.py> [args...]}"
shift || true

PASS=$("$ANSIBLE_PY" - "$VAULT" <<'PYEOF'
import sys, re
from pathlib import Path
from ansible.parsing.vault import VaultLib, VaultSecret
s = VaultSecret((Path.home()/".aurora-vault-pass").read_bytes().strip())
v = VaultLib([("labadmin", s)])
txt = v.decrypt(Path(sys.argv[1]).read_bytes()).decode()
sys.stdout.write(re.search(r':\s*"(.*)"', txt).group(1))
PYEOF
)

CTL=$(mktemp -u /tmp/ncfwd-iosxe.XXXXXX)
ssh -M -S "$CTL" -f -N -o BatchMode=yes -o ExitOnForwardFailure=yes -L 8830:"$NODE":830 "$BAST"
trap 'ssh -S "$CTL" -O exit "$BAST" 2>/dev/null || true' EXIT
sleep 2

cd "$HERE"
NC_USER="${NC_USER:-labadmin}" AURORA_TRANSIT_PASSWORD="$PASS" "$NETPY" "$SCRIPT" "$@"
