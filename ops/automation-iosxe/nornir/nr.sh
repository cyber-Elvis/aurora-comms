#!/usr/bin/env bash
# Generic Nornir runner for the IOS-XE transit nodes: decrypts the labadmin secret from
# the Ansible vault and runs a Nornir/Netmiko task script in the shared lab venv.
#   Usage: bash nr.sh <script.py> [args...]
#     bash nr.sh conntest.py 10.255.191.21
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ANSIBLE_PY=/home/fourty3/.local/share/pipx/venvs/ansible-core/bin/python
NORNIR_PY="$HOME/nornir-lab/venv/bin/python"
VAULT=/mnt/d/CyberLab/Repos/aurora-comms/ops/automation-iosxe/group_vars/transit/vault.yml

SCRIPT="${1:?usage: bash nr.sh <script.py> [args...]}"
shift

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
cd "$HERE"
AURORA_TRANSIT_PASSWORD="$PASS" "$NORNIR_PY" "$SCRIPT" "$@"
