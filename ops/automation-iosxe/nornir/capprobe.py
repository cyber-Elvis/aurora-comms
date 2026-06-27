#!/usr/bin/env python3
"""Read-only capability probe: which model-driven transports does this IOS-XE image
support? Runs show commands via Netmiko (graceful on '% Invalid input') so we can tell
NETCONF/RESTCONF/gNMI support BEFORE enabling anything. Password from AURORA_TRANSIT_PASSWORD."""
import os, sys
from netmiko import ConnectHandler

host = sys.argv[1] if len(sys.argv) > 1 else "10.255.191.21"
dev = {
    "device_type": "cisco_ios",
    "host": host,
    "username": "labadmin",
    "password": os.environ["AURORA_TRANSIT_PASSWORD"],
    "use_keys": False,
    "ssh_config_file": "/mnt/d/CyberLab/Repos/aurora-comms/ops/automation-iosxe/nornir/ssh_config",
    "disabled_algorithms": {"pubkeys": ["rsa-sha2-256", "rsa-sha2-512"]},
    "conn_timeout": 30,
    "fast_cli": False,
}
probes = [
    "show platform software yang-management process",   # NETCONF/RESTCONF infra (nesd/ncsshd/...)
    "show gnmi-yang state",                              # gNMI agent
    "show run | include ^netconf-yang|^restconf|^gnmi|^ip http",  # current config
]
c = ConnectHandler(**dev)
print("PROMPT:", c.find_prompt())
for cmd in probes:
    print(f"\n----- {cmd} -----")
    print(c.send_command(cmd, read_timeout=25))
c.disconnect()
