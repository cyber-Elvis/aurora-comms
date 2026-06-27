#!/usr/bin/env python3
"""NETCONF capability probe for the IOS-XE transit node (CSR). Connects to 127.0.0.1:8830
(the bastion :830 forward nc.sh sets up) and lists advertised capabilities / YANG models.
Creds from env (NC_USER / AURORA_TRANSIT_PASSWORD), set by nc.sh."""
import os
import paramiko
from ncclient import manager

# IOS-XE NETCONF SSH presents an RSA host key and negotiates group14 KEX (same as the CLI).
T = paramiko.Transport
if "diffie-hellman-group14-sha1" in T._kex_info and "diffie-hellman-group14-sha1" not in T._preferred_kex:
    T._preferred_kex = T._preferred_kex + ("diffie-hellman-group14-sha1",)
T._preferred_keys = ("ssh-rsa",) + tuple(k for k in T._preferred_keys if k != "ssh-rsa")

m = manager.connect(
    host="127.0.0.1", port=8830,
    username=os.environ["NC_USER"], password=os.environ["AURORA_TRANSIT_PASSWORD"],
    hostkey_verify=False, allow_agent=False, look_for_keys=False, timeout=30,
    device_params={"name": "csr"},   # ncclient IOS-XE / CSR handler
)
caps = list(m.server_capabilities)
m.close_session()

print(f"connected as {os.environ['NC_USER']} -- {len(caps)} capabilities advertised")
for kw in ("netconf:base:1.1", "writable-running", "rollback-on-error", "ietf-interfaces", "Cisco-IOS-XE-native"):
    hit = sorted({c for c in caps if kw.lower() in c.lower()})
    print(f"  {kw:24} : {'yes' if hit else 'no'}")
print("RESULT: OK")
