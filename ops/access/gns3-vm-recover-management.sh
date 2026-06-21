#!/usr/bin/env sh
set -eu

# Run on the GNS3 VM console after a VM restart if SSH, GNS3 API, or the
# Aurora management TAP is not reachable from PC1/Termius.

TAP_IF="${TAP_IF:-tap-aurora-mgmt}"
TAP_IP="${TAP_IP:-10.255.191.1/24}"
TAP_USER="${TAP_USER:-gns3}"

need_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo $0" >&2
    exit 1
  fi
}

start_if_present() {
  unit="$1"
  if systemctl list-unit-files "$unit" >/dev/null 2>&1; then
    systemctl enable --now "$unit" >/dev/null 2>&1 || systemctl restart "$unit" || true
  fi
}

need_root

cat >/etc/systemd/system/aurora-mgmt-tap.service <<EOF
[Unit]
Description=Aurora GNS3 management TAP
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -lc 'ip link show ${TAP_IF} >/dev/null 2>&1 || ip tuntap add dev ${TAP_IF} mode tap user ${TAP_USER}; ip addr replace ${TAP_IP} dev ${TAP_IF}; ip link set ${TAP_IF} up'
ExecStop=/bin/bash -lc 'ip link set ${TAP_IF} down || true; ip tuntap del dev ${TAP_IF} mode tap || true'

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

start_if_present ssh.service
start_if_present sshd.service
start_if_present tailscaled.service
start_if_present gns3.service
start_if_present gns3vm.service
start_if_present gns3server.service
systemctl enable --now aurora-mgmt-tap.service

echo
echo "== Interfaces =="
ip -br addr show "$TAP_IF" || true
ip -br addr show | sed -n '1,12p'

echo
echo "== Listening TCP ports =="
ss -lntp 2>/dev/null | grep -E ':(22|80|3080|5001|5003|5006|5007)\b' || true

echo
echo "== Service status =="
systemctl --no-pager --full status ssh.service sshd.service gns3.service gns3vm.service gns3server.service aurora-mgmt-tap.service 2>/dev/null || true

echo
echo "== Router management probes =="
for ip in 10.255.191.11 10.255.191.12 10.255.191.15 10.255.191.17; do
  ping -c 1 -W 1 "$ip" >/dev/null 2>&1 && echo "$ip ping ok" || echo "$ip ping failed"
  nc -vz -w 2 "$ip" 22 >/dev/null 2>&1 && echo "$ip tcp/22 ok" || echo "$ip tcp/22 failed"
done
