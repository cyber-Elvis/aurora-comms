#!/usr/bin/env python3
"""Generate Aurora multi-vendor manual configs.

Produces 12 router config files (4 routers x 3 vendors) under
outputs/aurora-docs/lab-manual/{frr,cisco-ios,nokia-sros}/.

Network design data lives in ROUTERS below — same data shape that
host_vars/<router>.yml will hold once Ansible automation lands.
This generator is the manual equivalent of a Jinja2 render step.
"""

from pathlib import Path

OUTPUT_BASE = Path("/sessions/relaxed-blissful-maxwell/mnt/outputs/aurora-docs/lab-manual")

ROUTERS = {
    "melbourne": {
        "loopback": "10.0.0.1",
        "sysid": "0010.0000.0001",
        "interfaces": [
            # (frr_iface, cisco_iface,             nokia_port, ip,            neighbor)
            ("eth1",     "GigabitEthernet0/0/0/0", "1/1/1",    "10.1.12.0/31", "sydney"),
            ("eth2",     "GigabitEthernet0/0/0/1", "1/1/2",    "10.1.14.0/31", "geelong"),
            ("eth3",     "GigabitEthernet0/0/0/2", "1/1/3",    "10.1.13.0/31", "brisbane"),
        ],
    },
    "sydney": {
        "loopback": "10.0.0.2",
        "sysid": "0010.0000.0002",
        "interfaces": [
            ("eth1", "GigabitEthernet0/0/0/0", "1/1/1", "10.1.12.1/31", "melbourne"),
            ("eth2", "GigabitEthernet0/0/0/1", "1/1/2", "10.1.23.0/31", "brisbane"),
            ("eth3", "GigabitEthernet0/0/0/2", "1/1/3", "10.1.24.0/31", "geelong"),
        ],
    },
    "brisbane": {
        "loopback": "10.0.0.3",
        "sysid": "0010.0000.0003",
        "interfaces": [
            ("eth1", "GigabitEthernet0/0/0/0", "1/1/1", "10.1.23.1/31", "sydney"),
            ("eth2", "GigabitEthernet0/0/0/1", "1/1/2", "10.1.34.0/31", "geelong"),
            ("eth3", "GigabitEthernet0/0/0/2", "1/1/3", "10.1.13.1/31", "melbourne"),
        ],
    },
    "geelong": {
        "loopback": "10.0.0.4",
        "sysid": "0010.0000.0004",
        "interfaces": [
            ("eth1", "GigabitEthernet0/0/0/0", "1/1/1", "10.1.34.1/31", "brisbane"),
            ("eth2", "GigabitEthernet0/0/0/1", "1/1/2", "10.1.14.1/31", "melbourne"),
            ("eth3", "GigabitEthernet0/0/0/2", "1/1/3", "10.1.24.1/31", "sydney"),
        ],
    },
}

ALL_LOOPBACKS = [r["loopback"] for r in ROUTERS.values()]
BGP_AS = 65100
ISIS_AREA = "49.0001"


def ibgp_peers(this_loopback):
    return [lo for lo in ALL_LOOPBACKS if lo != this_loopback]


def gen_frr(name, data):
    interfaces = data["interfaces"]
    peers = ibgp_peers(data["loopback"])

    lines = [
        "frr defaults traditional",
        f"hostname {name}",
        "service integrated-vtysh-config",
        "!",
        "interface lo",
        f" ip address {data['loopback']}/32",
        " ip router isis CORE",
        " isis circuit-type level-2-only",
        "!",
    ]
    for frr_iface, _, _, ip, neighbor in interfaces:
        lines += [
            f"interface {frr_iface}",
            f" description to-{neighbor}",
            f" ip address {ip}",
            " ip router isis CORE",
            " isis network point-to-point",
            " isis circuit-type level-2-only",
            " mpls ldp",
            "!",
        ]
    lines += [
        "router isis CORE",
        f" net {ISIS_AREA}.{data['sysid']}.00",
        " is-type level-2-only",
        " metric-style wide",
        " lsp-gen-interval 5",
        "!",
        "mpls ldp",
        f" router-id {data['loopback']}",
        " !",
        " address-family ipv4",
        f"  discovery transport-address {data['loopback']}",
    ]
    for frr_iface, _, _, _, _ in interfaces:
        lines.append(f"  interface {frr_iface}")
    lines += [
        " exit-address-family",
        " !",
        "!",
        f"router bgp {BGP_AS}",
        f" bgp router-id {data['loopback']}",
        " no bgp ebgp-requires-policy",
        " neighbor IBGP_PE peer-group",
        f" neighbor IBGP_PE remote-as {BGP_AS}",
        " neighbor IBGP_PE update-source lo",
    ]
    for peer in peers:
        lines.append(f" neighbor {peer} peer-group IBGP_PE")
    lines += [
        " !",
        " address-family ipv4 unicast",
        f"  network {data['loopback']}/32",
        "  neighbor IBGP_PE activate",
        "  neighbor IBGP_PE next-hop-self",
        " exit-address-family",
        "!",
        "end",
    ]
    return "\n".join(lines) + "\n"


def gen_cisco_iosxr(name, data):
    interfaces = data["interfaces"]
    peers = ibgp_peers(data["loopback"])

    lines = [
        f"! Cisco IOS-XR equivalent — Aurora {name.title()} PE",
        "!",
        f"hostname {name}",
        "!",
        "interface Loopback0",
        " description router-id",
        f" ipv4 address {data['loopback']} 255.255.255.255",
        "!",
    ]
    for _, ios_iface, _, ip, neighbor in interfaces:
        lines += [
            f"interface {ios_iface}",
            f" description to-{neighbor}",
            f" ipv4 address {ip}",
            "!",
        ]
    lines += [
        "router isis CORE",
        f" net {ISIS_AREA}.{data['sysid']}.00",
        " is-type level-2-only",
        " address-family ipv4 unicast",
        "  metric-style wide",
        " !",
        " interface Loopback0",
        "  passive",
        "  address-family ipv4 unicast",
        "  !",
        " !",
    ]
    for _, ios_iface, _, _, _ in interfaces:
        lines += [
            f" interface {ios_iface}",
            "  point-to-point",
            "  address-family ipv4 unicast",
            "  !",
            " !",
        ]
    lines += [
        "!",
        "mpls ldp",
        f" router-id {data['loopback']}",
        " address-family ipv4",
        " !",
    ]
    for _, ios_iface, _, _, _ in interfaces:
        lines += [f" interface {ios_iface}", " !"]
    lines += [
        "!",
        f"router bgp {BGP_AS}",
        f" bgp router-id {data['loopback']}",
        " address-family ipv4 unicast",
        " !",
        " neighbor-group IBGP_PE",
        f"  remote-as {BGP_AS}",
        "  update-source Loopback0",
        "  address-family ipv4 unicast",
        "   next-hop-self",
        "  !",
        " !",
    ]
    for peer in peers:
        lines += [
            f" neighbor {peer}",
            "  use neighbor-group IBGP_PE",
            " !",
        ]
    lines += [
        "!",
        "end",
    ]
    return "\n".join(lines) + "\n"


def gen_nokia_sros(name, data):
    interfaces = data["interfaces"]
    peers = ibgp_peers(data["loopback"])

    lines = [
        f"# Nokia 7750 SR equivalent — Aurora {name.title()} PE",
        "# SR OS classic CLI",
        "",
        'configure router "Base"',
        '    interface "system"',
        '        description "router-id"',
        f"        address {data['loopback']}/32",
        "        no shutdown",
        "    exit",
    ]
    for _, _, port, ip, neighbor in interfaces:
        lines += [
            f'    interface "to-{neighbor}"',
            f"        port {port}",
            f"        address {ip}",
            "        no shutdown",
            "    exit",
        ]
    lines += [
        f"    autonomous-system {BGP_AS}",
        f"    router-id {data['loopback']}",
        "",
        "    isis",
        "        level-capability level-2",
        f"        area-id {ISIS_AREA}",
        f"        system-id {data['sysid']}",
        "        level 2",
        "            wide-metrics-only",
        "        exit",
        '        interface "system"',
        "            passive",
        "            no shutdown",
        "        exit",
    ]
    for _, _, _, _, neighbor in interfaces:
        lines += [
            f'        interface "to-{neighbor}"',
            "            interface-type point-to-point",
            "            level-capability level-2",
            "            no shutdown",
            "        exit",
        ]
    lines += [
        "        no shutdown",
        "    exit",
        "",
        "    ldp",
        "        interface-parameters",
    ]
    for _, _, _, _, neighbor in interfaces:
        lines += [
            f'            interface "to-{neighbor}"',
            "                no shutdown",
            "            exit",
        ]
    lines += [
        "        exit",
        "        no shutdown",
        "    exit",
        "",
        "    bgp",
        f"        router-id {data['loopback']}",
        '        group "IBGP_PE"',
        "            type internal",
        f"            peer-as {BGP_AS}",
        "            local-address system",
        "            family ipv4",
        "            next-hop-self",
    ]
    for peer in peers:
        lines += [
            f"            neighbor {peer}",
            "            exit",
        ]
    lines += [
        "        exit",
        "        no shutdown",
        "    exit",
        "exit all",
    ]
    return "\n".join(lines) + "\n"


def main():
    OUTPUT_BASE.mkdir(parents=True, exist_ok=True)
    for vendor_dir in ["frr", "cisco-ios", "nokia-sros"]:
        (OUTPUT_BASE / vendor_dir).mkdir(parents=True, exist_ok=True)

    for name, data in ROUTERS.items():
        (OUTPUT_BASE / "frr" / f"{name}.conf").write_text(gen_frr(name, data))
        (OUTPUT_BASE / "cisco-ios" / f"{name}.cfg").write_text(gen_cisco_iosxr(name, data))
        (OUTPUT_BASE / "nokia-sros" / f"{name}.cli").write_text(gen_nokia_sros(name, data))

    print("Generated config files under", OUTPUT_BASE)
    for f in sorted(OUTPUT_BASE.rglob("*")):
        if f.is_file():
            print(" ", f.relative_to(OUTPUT_BASE))


if __name__ == "__main__":
    main()
