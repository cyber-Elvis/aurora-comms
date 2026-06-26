#!/usr/bin/env python3
"""Open an interactive legacy IOS-XR SSH session using a one-use password FIFO."""

import os
import re
import sys

import pexpect


if len(sys.argv) != 4:
    raise SystemExit("Usage: xr-interactive.py <host> <user> <password-fifo>")

host, user, fifo_path = sys.argv[1:]
if not re.fullmatch(r"[A-Za-z0-9_.:-]+", host):
    raise SystemExit("Invalid host.")
if not re.fullmatch(r"[A-Za-z0-9_.-]+", user):
    raise SystemExit("Invalid username.")

with open(fifo_path, "r", encoding="utf-8") as fifo:
    password = fifo.readline().rstrip("\r\n")
os.unlink(fifo_path)
if not password:
    raise SystemExit("Password input is empty.")

known_hosts = os.path.expanduser("~/.ssh/aurora_iosxr_known_hosts")
os.makedirs(os.path.dirname(known_hosts), mode=0o700, exist_ok=True)
args = [
    "-tt",
    "-o",
    "StrictHostKeyChecking=accept-new",
    "-o",
    f"UserKnownHostsFile={known_hosts}",
    "-o",
    "KexAlgorithms=+diffie-hellman-group14-sha1",
    "-o",
    "HostKeyAlgorithms=+ssh-rsa",
    "-o",
    "PubkeyAuthentication=no",
    f"{user}@{host}",
]
prompt = r"RP/\d+/\d+/CPU\d+:[-\w]+#"

child = pexpect.spawn("ssh", args, encoding="utf-8", timeout=45)
child.expect("[Pp]assword:")
child.sendline(password)
password = ""
result = child.expect([prompt, "[Pp]assword:", "Permission denied"])
if result != 0:
    raise SystemExit("Authentication failed.")
child.sendline("terminal length 0")
child.expect(prompt)
child.interact()
