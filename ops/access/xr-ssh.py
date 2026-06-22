#!/usr/bin/env python3
"""Run IOS-XR show commands over SSH with password auth + legacy KEX, via pexpect.

Runs FROM the GNS3 VM (which reaches node mgmt 10.255.191.x directly). XRv 6.1.3's
SSH server only offers legacy diffie-hellman-group14-sha1 KEX + ssh-rsa host keys
(disabled by default in modern OpenSSH) and wants a real interactive PTY, not an
exec channel — both handled here.

Usage:
    AC_PW='<password>' python3 xr-ssh.py <host> [user]   # commands on stdin, one per line
Example:
    printf 'show user tasks\\nshow isis adjacency\\n' | AC_PW=... python3 xr-ssh.py 10.255.191.15 aurora-claude
"""
import sys, os, pexpect

host = sys.argv[1]
user = sys.argv[2] if len(sys.argv) > 2 else 'aurora-claude'
pw = os.environ.get('AC_PW', '')
cmds = [l for l in sys.stdin.read().splitlines() if l.strip()] or ['show user tasks']

opts = ("-tt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "
        "-o KexAlgorithms=+diffie-hellman-group14-sha1 "
        "-o HostKeyAlgorithms=+ssh-rsa -o PubkeyAuthentication=no "
        "-o ConnectTimeout=20")
PROMPT = r'RP/\d+/\d+/CPU\d+:[-\w]+#'

child = pexpect.spawn(f"ssh {opts} {user}@{host}", encoding='utf-8', timeout=45)
try:
    child.expect('[Pp]assword:')
    child.sendline(pw)
    i = child.expect([PROMPT, '[Pp]assword:', 'Permission denied'])
    if i != 0:
        print("AUTH FAILED")
        sys.exit(1)
    child.sendline('terminal length 0')
    child.expect(PROMPT)
    for c in cmds:
        child.sendline(c)
        child.expect(PROMPT)
        print(f"\n===== {c} =====")
        print(child.before.strip())
    child.sendline('exit')
except pexpect.TIMEOUT:
    print("TIMEOUT. Buffer so far:\n" + (child.before or ''))
except pexpect.EOF:
    print("EOF. Buffer so far:\n" + (child.before or ''))
