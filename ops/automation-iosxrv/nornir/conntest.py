#!/usr/bin/env python3
"""Phase 2 connection proof: Netmiko -> XRv 6.1.3 via the GNS3 bastion.
Password comes from AURORA_XR_PASSWORD (so no secret on disk/argv)."""
import os, sys
from netmiko import ConnectHandler

host = sys.argv[1] if len(sys.argv) > 1 else "10.255.191.17"
dev = {
    "device_type": "cisco_xr",
    "host": host,
    "username": "aurora-automation",
    "password": os.environ["AURORA_XR_PASSWORD"],
    "use_keys": False,
    "ssh_config_file": "/mnt/d/CyberLab/Repos/aurora-comms/ops/automation-iosxrv/nornir/ssh_config",
    "disabled_algorithms": {"pubkeys": ["rsa-sha2-256", "rsa-sha2-512"]},
    "conn_timeout": 30,
    "fast_cli": False,
}
try:
    c = ConnectHandler(**dev)
    print("CONNECTED prompt:", c.find_prompt())
    print(c.send_command("show version | include Version"))
    c.disconnect()
    print("RESULT: OK")
except Exception as e:
    print("RESULT: NETMIKO-FAIL:", type(e).__name__, "-", str(e)[:400])
