#!/usr/bin/env python3
# Minimal read-only TFTP server (octet mode) for staging files onto IOS-XR nodes
# from the GNS3 VM (which holds 10.255.191.1 on tap-aurora-mgmt, the mgmt host the
# node ACLs trust). Serves files from ROOT. Run as root (port 69):
#   sudo python3 gns3-tftp-serve.py
# On the router:  copy tftp://10.255.191.1/<file> harddisk:/<file>
import socket, struct, os
ROOT = '/home/gns3'
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(('0.0.0.0', 69))
while True:
    data, addr = s.recvfrom(1500)
    if struct.unpack('!H', data[:2])[0] != 1:   # RRQ only
        continue
    fname = data[2:].split(b'\x00')[0].decode('ascii', 'ignore')
    path = os.path.join(ROOT, os.path.basename(fname))
    t = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    t.bind(('0.0.0.0', 0)); t.settimeout(3)
    if not os.path.isfile(path):
        t.sendto(b'\x00\x05\x00\x01file not found\x00', addr); t.close(); continue
    with open(path, 'rb') as f:
        blk = 1
        while True:
            chunk = f.read(512)
            pkt = struct.pack('!HH', 3, blk) + chunk
            ok = False
            for _ in range(6):
                t.sendto(pkt, addr)
                try:
                    ack, _ = t.recvfrom(64)
                    if struct.unpack('!H', ack[:2])[0] == 4 and struct.unpack('!H', ack[2:4])[0] == blk:
                        ok = True; break
                except socket.timeout:
                    pass
            if not ok:
                break
            blk = (blk + 1) & 0xFFFF
            if len(chunk) < 512:
                break
    t.close()
