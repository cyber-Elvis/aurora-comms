#!/usr/bin/env python3
"""Read-only NETCONF capability probe — feasibility check for later tiers.

Lists the device's advertised capabilities / YANG models matching management
keywords (grpc, gnmi, ems, telemetry, restconf, http) so we can tell, before
investing, whether a node exposes the gRPC/gNMI or RESTCONF management planes.

  bash nc.sh nc_caps.py            probe NC_NODE (default ADL)

Connects to 127.0.0.1:8830 (the bastion :830 forward that nc.sh sets up).
Creds from env (NC_USER / AURORA_XR_PASSWORD), set by nc.sh.
"""
import os

import paramiko
from ncclient import manager

T = paramiko.Transport
if "diffie-hellman-group14-sha1" in T._kex_info and "diffie-hellman-group14-sha1" not in T._preferred_kex:
    T._preferred_kex = T._preferred_kex + ("diffie-hellman-group14-sha1",)
T._preferred_keys = ("ssh-rsa",) + tuple(k for k in T._preferred_keys if k != "ssh-rsa")

KEYWORDS = ("grpc", "gnmi", "ems", "telemetry", "mdt", "restconf", "http")

m = manager.connect(
    host="127.0.0.1", port=8830,
    username=os.environ["NC_USER"], password=os.environ["AURORA_XR_PASSWORD"],
    hostkey_verify=False, allow_agent=False, look_for_keys=False, timeout=30,
    device_params={"name": "iosxr"},
)
caps = list(m.server_capabilities)
m.close_session()

print(f"connected as {os.environ['NC_USER']} — {len(caps)} capabilities advertised")
hits = sorted({c for c in caps for k in KEYWORDS if k in c.lower()})
if hits:
    print(f"management-plane models matching {KEYWORDS}:")
    for h in hits:
        print(f"  {h}")
else:
    print(f"NO capabilities match {KEYWORDS} — gRPC/gNMI/RESTCONF models not advertised.")
