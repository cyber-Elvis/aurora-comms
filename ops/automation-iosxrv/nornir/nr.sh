#!/usr/bin/env bash
# Generic Nornir runner: decrypts the aurora-automation secret from the Ansible
# vault and runs a Nornir task script in the lab venv.
#   Usage: bash nr.sh <script.py> [args...]
#     bash nr.sh show_version.py
#     bash nr.sh show_version.py "show isis neighbors"
#     bash nr.sh backup_configs.py
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ANSIBLE_PY=/home/fourty3/.local/share/pipx/venvs/ansible-core/bin/python
NORNIR_PY="$HOME/nornir-lab/venv/bin/python"
VAULT=/mnt/d/CyberLab/Repos/aurora-comms/ops/automation-iosxrv/group_vars/region_a_iosxr/vault.yml

SCRIPT="${1:?usage: bash nr.sh <script.py> [args...]}"
shift

PASS=$("$ANSIBLE_PY" - "$VAULT" <<'PYEOF'
import sys, re
from pathlib import Path
from ansible.parsing.vault import VaultLib, VaultSecret
s = VaultSecret((Path.home()/".aurora-vault-pass").read_bytes().strip())
v = VaultLib([("automation", s)])
txt = v.decrypt(Path(sys.argv[1]).read_bytes()).decode()
sys.stdout.write(re.search(r':\s*"(.*)"', txt).group(1))
PYEOF
)
cd "$HERE"
AURORA_XR_PASSWORD="$PASS" "$NORNIR_PY" "$SCRIPT" "$@"
