# MOP: ADL-PE1 Termius discovery

## Objective

Bootstrap management SSH on `ADL-PE1-CISCO-IOL-RT01`, then discover it from
PC3 Termius through the existing `PC2 GNS3 Jump`.

This MOP configures management access only. The ADL-GEL core link, IS-IS, LDP,
and VPNv4 are a separate change.

## Approved path

```text
PC3 Termius
  -> gns3@100.118.0.46
  -> tap-aurora-mgmt 10.255.191.1
  -> MGMT-SW01
  -> ADL-PE1 Ethernet0/1 10.255.191.17/24
```

## API pre-check

| Item | Expected |
| --- | --- |
| Project | `ops-lab` |
| ADL node ID | `219d6471-1304-45b0-8a5c-71fc0f683458` |
| State | `started` |
| Console | GNS3 VM TCP `5007` |
| Core link | ADL `Ethernet0/0` to GEL `Ethernet0/2` |
| Management link | ADL `Ethernet0/1` to MGMT-SW01 `Ethernet0/5` |

## Phase 1: open the console

In Termius, open `PC2 GNS3 Jump`, then run:

```bash
telnet 127.0.0.1 5007
```

Press Enter until the IOS prompt appears. Do not paste configuration until the
device has finished booting.

## Phase 2: management bootstrap

Choose distinct strong local `admin` and enable secrets. Use IOS type 9 scrypt.
Do not place plaintext secrets or their resulting hashes in this document,
terminal captures, or screenshots.

Type the following commands:

```ios
enable
configure terminal
hostname ADL-PE1-CISCO-IOL-RT01
no ip domain lookup
ip domain name lab.aurora
service password-encryption
enable algorithm-type scrypt secret <SET_ENABLE_SECRET>
username admin privilege 15 algorithm-type scrypt secret <SET_ADMIN_SECRET>

interface Ethernet0/1
 description OOB_MGMT_TO_MGMT-SW01
 ip address 10.255.191.17 255.255.255.0
 no shutdown
 exit

crypto key generate rsa modulus 2048
ip ssh version 2
ip ssh time-out 60
ip ssh authentication-retries 3
login block-for 60 attempts 3 within 30

ip ssh pubkey-chain
 username admin
  key-string
   AAAAC3NzaC1lZDI1NTE5AAAAID7O3FAUgegskGDyKkImQcXbDSeipsKIJaeKFHysPiCu
  exit
 exit

ip access-list standard MGMT-SOURCES
 permit host 10.255.191.1
 deny any log
 exit

line vty 0 4
 transport input ssh
 login local
 access-class MGMT-SOURCES in
 exec-timeout 10 0
 exit

end
write memory
```

If IOS reports that RSA keys already exist, retain them and continue with the
remaining commands.

## Phase 3: console verification

Run and retain the output:

```ios
show clock
show ip interface brief | include Ethernet0/1
show interfaces Ethernet0/1 | include line protocol|Internet address
show ip ssh
show access-lists MGMT-SOURCES
show running-config | section line vty
show running-config | section ip ssh pubkey-chain
show startup-config | include hostname
```

Expected:

```text
Ethernet0/1   10.255.191.17   ...   up   up
SSH Enabled - version 2.0
hostname ADL-PE1-CISCO-IOL-RT01
```

## Phase 4: Termius discovery

Create or update this Termius host:

| Field | Value |
| --- | --- |
| Label | `ADL-PE1` |
| Address | `10.255.191.17` |
| Port | `22` |
| Username | `admin` |
| Identity | `Aurora Node Admin` |
| Jump host | `PC2 GNS3 Jump` |

Do not enable SSH agent forwarding.

## Evidence template

```text
Change: ADL-PE1 management bootstrap and PC3 Termius discovery
Date/time:
Operator:

GNS3 API:
- Node state:
- Node ID:
- ADL e0/0 peer:
- ADL e0/1 peer:

Console:
- Hostname:
- Ethernet0/1 state:
- Management address:
- SSH version:
- Startup configuration saved: YES / NO

GNS3 VM verification:
- ping 10.255.191.17:
- TCP/22:

PC3 / Termius:
- Jump host used:
- Key authentication succeeded: YES / NO
- Prompt received:
- show users source:

Result: PASS / FAIL
Notes:
```

## Rollback

Use the console:

```ios
configure terminal
line vty 0 4
 no access-class MGMT-SOURCES in
 transport input none
 exit
interface Ethernet0/1
 shutdown
 no ip address
 exit
no username admin
end
write memory
```

Do not stop or delete ADL through the GNS3 GUI while collecting failure
evidence. The API state and console output are needed for diagnosis.
