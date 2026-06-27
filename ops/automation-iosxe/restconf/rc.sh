#!/usr/bin/env bash
# RESTCONF smoke test for the IOS-XE transit node (CSR only). Decrypt labadmin from the
# vault, open a bastion TCP forward to :443, GET a RESTCONF resource, tear the forward down.
#   bash rc.sh                                          -> GET native/hostname on transit-a
#   bash rc.sh data/ietf-interfaces:interfaces          -> GET another resource
#   RC_NODE=10.255.191.21 bash rc.sh
# NOTE: transit-b (IOL) has no RESTCONF/HTTP YANG agent — CSR transit-a (.21) only.
set -euo pipefail
ANSIBLE_PY=/home/fourty3/.local/share/pipx/venvs/ansible-core/bin/python
VAULT=/mnt/d/CyberLab/Repos/aurora-comms/ops/automation-iosxe/group_vars/transit/vault.yml
BAST=gns3@100.118.0.46
NODE="${RC_NODE:-10.255.191.21}"
RUSER="${RC_USER:-labadmin}"
PATHX="${1:-data/Cisco-IOS-XE-native:native/hostname}"
echo "==> RESTCONF GET ${NODE}:443/restconf/${PATHX} (via ${BAST})" >&2

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

CTL=$(mktemp -u /tmp/rcfwd.XXXXXX)
ssh -M -S "$CTL" -f -N -o BatchMode=yes -o ExitOnForwardFailure=yes -L 8443:"$NODE":443 "$BAST"
trap 'ssh -S "$CTL" -O exit "$BAST" 2>/dev/null || true' EXIT
sleep 2

# password via curl --config stdin so it never lands in argv/ps
printf 'user = "%s:%s"\n' "$RUSER" "$PASS" | \
  curl -sS -k --tls-max 1.2 --ciphers "DEFAULT@SECLEVEL=0" -H "Accept: application/yang-data+json" -K - \
  "https://127.0.0.1:8443/restconf/${PATHX}"
echo
