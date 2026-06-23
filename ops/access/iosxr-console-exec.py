#!/usr/bin/env python3
"""Run bounded EXEC-only commands on a GNS3 IOS-XR telnet console."""

import argparse
import select
import socket
import sys
import time


IAC = 255
DONT = 254
DO = 253
WONT = 252
WILL = 251
SB = 250
SE = 240


def receive(sock: socket.socket, duration: float) -> bytes:
    deadline = time.monotonic() + duration
    output = bytearray()
    while time.monotonic() < deadline:
        ready, _, _ = select.select([sock], [], [], min(0.1, deadline - time.monotonic()))
        if not ready:
            continue
        chunk = sock.recv(65535)
        if not chunk:
            break
        output.extend(chunk)
    return bytes(output)


def filter_telnet(sock: socket.socket, data: bytes) -> str:
    output = bytearray()
    response = bytearray()
    index = 0
    while index < len(data):
        byte = data[index]
        if byte != IAC or index + 1 >= len(data):
            output.append(byte)
            index += 1
            continue

        command = data[index + 1]
        if command in (DO, DONT, WILL, WONT) and index + 2 < len(data):
            option = data[index + 2]
            if command == DO:
                response.extend((IAC, WONT, option))
            elif command == WILL:
                response.extend((IAC, DONT, option))
            index += 3
            continue

        if command == SB:
            index += 2
            while index + 1 < len(data):
                if data[index] == IAC and data[index + 1] == SE:
                    index += 2
                    break
                index += 1
            continue

        index += 2

    if response:
        sock.sendall(response)
    return output.decode("utf-8", errors="replace")


def send_command(sock: socket.socket, command: str, wait: float) -> str:
    sock.sendall(command.encode("ascii") + b"\r")
    return filter_telnet(sock, receive(sock, wait))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("port", type=int)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--wait", type=float, default=2.0)
    parser.add_argument(
        "commands",
        nargs="*",
        help="EXEC commands only; configuration commands are rejected locally",
    )
    args = parser.parse_args()

    forbidden = ("conf", "configure", "commit", "admin", "reload")
    for command in args.commands:
        normalized = command.strip().lower()
        if normalized.startswith(forbidden):
            raise SystemExit(f"Refusing non-EXEC-safe command: {command}")

    with socket.create_connection((args.host, args.port), timeout=5) as sock:
        sock.setblocking(False)
        transcript = filter_telnet(sock, receive(sock, 1.0))
        transcript += send_command(sock, "", 1.0)
        for command in args.commands:
            transcript += send_command(sock, command, args.wait)
        sys.stdout.write(transcript)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
