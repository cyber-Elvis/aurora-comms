#!/usr/bin/env python3
"""Phase 2 Nornir task — back up every Region A node's running-config to
backups/<host>.cfg, concurrently. Read-only (show running-config)."""
import os
from pathlib import Path

from nornir import InitNornir
from nornir_netmiko.tasks import netmiko_send_command

nr = InitNornir(config_file="config.yaml")
# Creds reuse the Ansible vault (nr.sh exports the decrypted secret here).
nr.inventory.defaults.password = os.environ["AURORA_XR_PASSWORD"]

backup_dir = Path("backups")
backup_dir.mkdir(exist_ok=True)


def backup(task):
    res = task.run(task=netmiko_send_command, command_string="show running-config")
    path = backup_dir / f"{task.host.name}.cfg"
    path.write_text(res.result)
    return f"saved {path}  ({len(res.result.splitlines())} lines)"


result = nr.run(name="backup running-config", task=backup)

# Print only a per-host summary — the full configs (incl. secret hashes) stay in
# backups/, never echoed to the terminal.
print("\nconfig backup:")
for host in sorted(result):
    mr = result[host]
    print(f"  {host:<9} {'FAILED' if mr.failed else mr[0].result}")
