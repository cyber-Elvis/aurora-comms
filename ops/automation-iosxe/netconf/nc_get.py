#!/usr/bin/env python3
"""NETCONF get-config read smoke test for the IOS-XE transit node (CSR) — pulls the
hostname from the running datastore via 127.0.0.1:8830 (the nc.sh bastion forward)."""
import os
import xml.dom.minidom as minidom
import paramiko
from ncclient import manager

T = paramiko.Transport
if "diffie-hellman-group14-sha1" in T._kex_info and "diffie-hellman-group14-sha1" not in T._preferred_kex:
    T._preferred_kex = T._preferred_kex + ("diffie-hellman-group14-sha1",)
T._preferred_keys = ("ssh-rsa",) + tuple(k for k in T._preferred_keys if k != "ssh-rsa")

FILTER = '<native xmlns="http://cisco.com/ns/yang/Cisco-IOS-XE-native"><hostname/></native>'

m = manager.connect(
    host="127.0.0.1", port=8830,
    username=os.environ["NC_USER"], password=os.environ["AURORA_TRANSIT_PASSWORD"],
    hostkey_verify=False, allow_agent=False, look_for_keys=False, timeout=30,
    device_params={"name": "csr"},
)
r = m.get_config(source="running", filter=("subtree", FILTER))
m.close_session()
print(minidom.parseString(r.data_xml).toprettyxml(indent="  ").strip()[:1000])
print("RESULT: OK")
