#!/usr/bin/env sh
set -eu

# Apply on the GNS3 VM. This guards the live lab management TAP so lab nodes
# cannot initiate sessions to protected host-admin services.

CHAIN="AURORA-HOST-GUARD"
LAB_IF="${LAB_IF:-tap-aurora-mgmt}"
PC1_IP="${PC1_IP:-192.168.200.1}"
PC2_IP="${PC2_IP:-192.168.200.2}"
RPKI_RTR_PORT="${RPKI_RTR_PORT:-3323}"
PROTECTED_TCP_PORTS="${PROTECTED_TCP_PORTS:-22,135,139,445,2222,3080,3389,5985,5986,8000,8443,9090,10000}"

need_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root, for example: sudo $0 ${1:-apply}" >&2
    exit 1
  fi
}

chain_exists() {
  iptables -S "$CHAIN" >/dev/null 2>&1
}

jump_exists() {
  iptables -C FORWARD -i "$LAB_IF" -j "$CHAIN" >/dev/null 2>&1
}

apply_rules() {
  need_root "$@"

  if ! chain_exists; then
    iptables -N "$CHAIN"
  fi

  iptables -F "$CHAIN"

  # Explicit service exception from lab nodes to the PC1 RPKI-RTR cache.
  iptables -A "$CHAIN" -d "$PC1_IP" -p tcp --dport "$RPKI_RTR_PORT" -j ACCEPT

  for host_ip in "$PC1_IP" "$PC2_IP"; do
    iptables -A "$CHAIN" -d "$host_ip" -p tcp -m multiport --dports "$PROTECTED_TCP_PORTS" \
      -m limit --limit 12/min --limit-burst 20 \
      -j LOG --log-prefix "AURORA_HOST_GUARD denied " --log-level 4
    iptables -A "$CHAIN" -d "$host_ip" -p tcp -m multiport --dports "$PROTECTED_TCP_PORTS" \
      -j REJECT --reject-with tcp-reset
  done

  iptables -A "$CHAIN" -j RETURN

  if ! jump_exists; then
    iptables -I FORWARD 1 -i "$LAB_IF" -j "$CHAIN"
  fi
}

remove_rules() {
  need_root "$@"

  while jump_exists; do
    iptables -D FORWARD -i "$LAB_IF" -j "$CHAIN"
  done

  if chain_exists; then
    iptables -F "$CHAIN"
    iptables -X "$CHAIN"
  fi
}

status_rules() {
  iptables -S FORWARD | grep -- "$CHAIN" || true
  if chain_exists; then
    iptables -L "$CHAIN" -n -v --line-numbers
  else
    echo "$CHAIN is not installed"
  fi
}

case "${1:-apply}" in
  apply)
    apply_rules "$@"
    status_rules
    ;;
  remove)
    remove_rules "$@"
    ;;
  status)
    status_rules
    ;;
  *)
    echo "Usage: $0 [apply|remove|status]" >&2
    exit 2
    ;;
esac
