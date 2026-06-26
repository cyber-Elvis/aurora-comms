#!/usr/bin/env python3
"""Write one stdin value to a standard Ansible Vault YAML file."""

import argparse
from pathlib import Path
import sys

from ansible.parsing.vault import VaultLib, VaultSecret


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--password-file")
    parser.add_argument("--output", required=True)
    parser.add_argument("--variable", required=True)
    parser.add_argument("--vault-id", default="codex")
    parser.add_argument(
        "--stream",
        action="store_true",
        help="Read vault password on stdin line 1 and value on line 2.",
    )
    args = parser.parse_args()

    if args.stream:
        lines = [line for line in sys.stdin.read().splitlines() if line]
        if len(lines) != 2:
            raise SystemExit("Stream input must contain exactly two lines.")
        password = lines[0].encode("utf-8")
        value = lines[1]
    else:
        if not args.password_file:
            raise SystemExit("--password-file is required unless --stream is used.")
        value = sys.stdin.read().rstrip("\r\n")
        password = Path(args.password_file).read_bytes().strip()

    if not value:
        raise SystemExit("Secret input is empty.")
    if not password:
        raise SystemExit("Vault password is empty.")

    vault_secret = VaultSecret(password)
    vault = VaultLib([(args.vault_id, vault_secret)])
    yaml = f'{args.variable}: "{value}"\n'.encode("utf-8")
    encrypted = vault.encrypt(
        yaml,
        secret=vault_secret,
        vault_id=args.vault_id,
    )

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(encrypted)
    decrypted = vault.decrypt(encrypted)
    if decrypted != yaml:
        raise SystemExit("Vault round-trip validation failed.")
    print(
        f"vault_id={args.vault_id} variable={args.variable} "
        f"value_length={len(value)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
