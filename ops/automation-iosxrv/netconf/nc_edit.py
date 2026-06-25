#!/usr/bin/env python3
"""Phase 3 NETCONF edit-config (WRITE) — candidate -> commit, MOP-driven.

Worked example: create a dedicated canary interface Loopback111, then delete it.
Self-contained + fully revertible (no existing config touched).

  bash nc.sh nc_edit.py             DRY-RUN : stage in candidate, show it, DISCARD (no change)
  bash nc.sh nc_edit.py --apply     APPLY   : stage + commit (creates Loopback111)
  bash nc.sh nc_edit.py --rollback  ROLLBACK: delete Loopback111 + commit

Connects to 127.0.0.1:8830 (the bastion :830 forward that nc.sh sets up).
Creds from env (NC_USER / AURORA_XR_PASSWORD), set by nc.sh.
"""
import os
import sys

import paramiko
from ncclient import manager

# IOS-XRv 6.1.3 legacy SSH: ensure group14-sha1 KEX + ssh-rsa host key (paramiko 4.0.0).
T = paramiko.Transport
if "diffie-hellman-group14-sha1" in T._kex_info and "diffie-hellman-group14-sha1" not in T._preferred_kex:
    T._preferred_kex = T._preferred_kex + ("diffie-hellman-group14-sha1",)
T._preferred_keys = ("ssh-rsa",) + tuple(k for k in T._preferred_keys if k != "ssh-rsa")

IFNAME = "Loopback111"
NS = "http://cisco.com/ns/yang/Cisco-IOS-XR-ifmgr-cfg"
NSIP = "http://cisco.com/ns/yang/Cisco-IOS-XR-ipv4-io-cfg"

CREATE = f"""<config>
  <interface-configurations xmlns="{NS}">
    <interface-configuration>
      <active>act</active>
      <interface-name>{IFNAME}</interface-name>
      <interface-virtual/>
      <ipv4-network xmlns="{NSIP}">
        <addresses><primary>
          <address>10.111.111.111</address>
          <netmask>255.255.255.255</netmask>
        </primary></addresses>
      </ipv4-network>
    </interface-configuration>
  </interface-configurations>
</config>"""

DELETE = f"""<config xmlns:nc="urn:ietf:params:xml:ns:netconf:base:1.0">
  <interface-configurations xmlns="{NS}">
    <interface-configuration nc:operation="delete">
      <active>act</active>
      <interface-name>{IFNAME}</interface-name>
    </interface-configuration>
  </interface-configurations>
</config>"""

FILTER = (
    f'<interface-configurations xmlns="{NS}"><interface-configuration>'
    f"<active>act</active><interface-name>{IFNAME}</interface-name>"
    f"</interface-configuration></interface-configurations>"
)

mode = sys.argv[1] if len(sys.argv) > 1 else "--check"
cfg = DELETE if mode == "--rollback" else CREATE

m = manager.connect(
    host="127.0.0.1", port=8830,
    username=os.environ["NC_USER"], password=os.environ["AURORA_XR_PASSWORD"],
    hostkey_verify=False, allow_agent=False, look_for_keys=False, timeout=30,
    device_params={"name": "iosxr"},
)
print(f"connected as {os.environ['NC_USER']}, session {m.session_id}")
m.edit_config(target="candidate", config=cfg)
candidate = m.get_config(source="candidate", filter=("subtree", FILTER)).data_xml
if mode in ("--apply", "--rollback"):
    m.commit()
    print(f"{IFNAME} {'DELETED' if mode == '--rollback' else 'CREATED'} + committed")
else:
    m.discard_changes()
    print(f"DRY-RUN candidate for {IFNAME} (discarded):")
    print(candidate)
m.close_session()
