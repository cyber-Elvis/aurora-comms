#!/usr/bin/env python3
"""Phase 3 NETCONF get-config (READ) — coach verification for the Loopback111 canary.

Read-only: get-config of the running datastore, filtered to the Loopback111
interface-configuration subtree. Prints the subtree if present, or a clear
"ABSENT" line if not. Used to verify the nc_edit.py apply/rollback:
  present with 10.111.111.111/32 after --apply, absent after --rollback.

  bash nc.sh nc_get.py            verify Loopback111 (running datastore)

Connects to 127.0.0.1:8830 (the bastion :830 forward that nc.sh sets up).
Creds from env (NC_USER / AURORA_XR_PASSWORD), set by nc.sh.
"""
import os

import paramiko
from ncclient import manager

# IOS-XRv 6.1.3 legacy SSH: ensure group14-sha1 KEX + ssh-rsa host key (paramiko 4.0.0).
T = paramiko.Transport
if "diffie-hellman-group14-sha1" in T._kex_info and "diffie-hellman-group14-sha1" not in T._preferred_kex:
    T._preferred_kex = T._preferred_kex + ("diffie-hellman-group14-sha1",)
T._preferred_keys = ("ssh-rsa",) + tuple(k for k in T._preferred_keys if k != "ssh-rsa")

IFNAME = "Loopback111"
NS = "http://cisco.com/ns/yang/Cisco-IOS-XR-ifmgr-cfg"

FILTER = (
    f'<interface-configurations xmlns="{NS}"><interface-configuration>'
    f"<active>act</active><interface-name>{IFNAME}</interface-name>"
    f"</interface-configuration></interface-configurations>"
)

m = manager.connect(
    host="127.0.0.1", port=8830,
    username=os.environ["NC_USER"], password=os.environ["AURORA_XR_PASSWORD"],
    hostkey_verify=False, allow_agent=False, look_for_keys=False, timeout=30,
    device_params={"name": "iosxr"},
)
print(f"connected as {os.environ['NC_USER']}, session {m.session_id}")
data = m.get_config(source="running", filter=("subtree", FILTER)).data_xml
m.close_session()

if IFNAME in data and "10.111.111.111" in data:
    print(f"{IFNAME} PRESENT with 10.111.111.111/32:")
    print(data)
elif IFNAME in data:
    print(f"{IFNAME} present (address not matched) — raw subtree:")
    print(data)
else:
    print(f"{IFNAME} ABSENT (running datastore has no such interface-configuration).")
    print(data)
