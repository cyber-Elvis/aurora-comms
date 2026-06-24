#!/usr/bin/env python3
"""Run bounded IOS-XR diagnostics with password auth and a real PTY.

Run this on the GNS3 VM, which reaches the 10.255.191.0/24 management network.
IOS-XRv 6.1.3 requires legacy group14-sha1 KEX and ssh-rsa host keys, and its
SSH server does not return command output through an exec channel.

Usage:
    AURORA_XR_PASSWORD='<password>' python3 xr-ssh.py <host> [user]
"""

import os
import re
import sys

import pexpect


if len(sys.argv) < 2:
    raise SystemExit("Usage: xr-ssh.py <host> [user]")

host = sys.argv[1]
user = sys.argv[2] if len(sys.argv) > 2 else "aurora-codex"
password = os.environ.get("AURORA_XR_PASSWORD") or os.environ.get("AC_PW", "")
input_lines = sys.stdin.read().splitlines()
if os.environ.get("AURORA_XR_PASSWORD_STDIN") == "1":
    if not input_lines:
        raise SystemExit("Password input is empty.")
    password = input_lines.pop(0)
commands = [line.strip() for line in input_lines if line.strip()]
commands = commands or ["show user tasks"]
authorization_probe = os.environ.get("AURORA_XR_AUTHZ_PROBE") == "1"

if not password:
    raise SystemExit("AURORA_XR_PASSWORD is required.")
if not re.fullmatch(r"[A-Za-z0-9_.:-]+", host):
    raise SystemExit("Invalid host.")
if not re.fullmatch(r"[A-Za-z0-9_.-]+", user):
    raise SystemExit("Invalid username.")

allowed_prefixes = ("show ", "ping ", "traceroute ", "debug ", "undebug ")
for command in commands:
    if not authorization_probe and not command.lower().startswith(allowed_prefixes):
        raise SystemExit(
            f"Refusing command outside the diagnostic allowlist: {command}"
        )
    if authorization_probe and command.lower() not in (
        "configure",
        "hostname authz-probe-do-not-commit",
        "show configuration",
        "abort",
    ):
        raise SystemExit(f"Refusing unsafe authorization probe: {command}")

known_hosts = os.path.expanduser("~/.ssh/aurora_iosxr_known_hosts")
os.makedirs(os.path.dirname(known_hosts), mode=0o700, exist_ok=True)
ssh_args = [
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
    "-o",
    "ConnectTimeout=20",
    f"{user}@{host}",
]
prompt = r"RP/\d+/\d+/CPU\d+:[-\w]+(?:\(config(?:-[^)]+)?\))?#"

child = pexpect.spawn("ssh", ssh_args, encoding="utf-8", timeout=45)
try:
    child.expect("[Pp]assword:")
    child.sendline(password)
    result = child.expect([prompt, "[Pp]assword:", "Permission denied"])
    if result != 0:
        print("AUTH FAILED")
        raise SystemExit(1)

    child.sendline("terminal length 0")
    child.expect(prompt)
    for command in commands:
        child.sendline(command)
        child.expect(prompt)
        print(f"\n===== {command} =====")
        print(child.before.strip())
    child.sendline("exit")
except pexpect.TIMEOUT:
    print("TIMEOUT. Buffer so far:\n" + (child.before or ""))
    raise SystemExit(2)
except pexpect.EOF:
    print("EOF. Buffer so far:\n" + (child.before or ""))
    raise SystemExit(3)
