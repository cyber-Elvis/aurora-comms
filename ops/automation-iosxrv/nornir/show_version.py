#!/usr/bin/env python3
"""Phase 2 Nornir task — run a read-only show command on every Region A node,
concurrently. Default command is 'show version | include Version'.

Usage (via run.sh, which injects the vault password):
    bash run.sh
    bash run.sh "show ip interface brief"
"""
import os
import sys
from nornir import InitNornir
from nornir_netmiko.tasks import netmiko_send_command
from nornir_utils.plugins.functions import print_result

nr = InitNornir(config_file="config.yaml")
# Creds reuse the Ansible vault: run.sh decrypts aurora-automation and exports it here.
nr.inventory.defaults.password = os.environ["AURORA_XR_PASSWORD"]

command = sys.argv[1] if len(sys.argv) > 1 else "show version | include Version"


def gather(task):
    task.run(task=netmiko_send_command, command_string=command)


print_result(nr.run(name=command, task=gather))
