# Wazuh denied-flow alerts

Aurora host containment should produce an alert when a lab node attempts a
protected host service on PC1 or PC2/Dell.

Protected services:

```text
22,135,139,445,2222,3080,3389,5985,5986,8000,8443,9090,10000
```

Allowed exception:

```text
192.168.137.1:3323/tcp  RPKI-RTR
```

## Manager install

On the Wazuh manager, place:

```text
aurora-host-containment-rules.xml -> /var/ossec/etc/rules/aurora-host-containment-rules.xml
```

Then restart the manager:

```bash
sudo systemctl restart wazuh-manager
```

If the manager receives direct syslog from routers, add a syslog listener in
`/var/ossec/etc/ossec.conf`:

```xml
<remote>
  <connection>syslog</connection>
  <port>514</port>
  <protocol>udp</protocol>
  <allowed-ips>10.255.191.0/24</allowed-ips>
</remote>
```

The GNS3 VM guard logs to the kernel log with prefix
`AURORA_HOST_GUARD denied`. Collect that log with a Wazuh agent on the GNS3 VM
or forward it through syslog to the manager.

## Normalized JSON event

When a firewall or log forwarder can normalize events, use this shape:

```json
{
  "aurora": {
    "control": "host-containment",
    "action": "deny",
    "src_zone": "lab",
    "dst_zone": "host"
  },
  "source": {
    "ip": "10.255.191.11"
  },
  "destination": {
    "ip": "192.168.137.1",
    "port": 22
  }
}
```

The permitted RPKI exception can be sent at a low level:

```json
{
  "aurora": {
    "control": "host-containment",
    "action": "allow",
    "src_zone": "lab",
    "dst_zone": "host"
  },
  "source": {
    "ip": "10.255.191.14"
  },
  "destination": {
    "ip": "192.168.137.1",
    "port": 3323
  }
}
```

## Rule test

On the Wazuh manager:

```bash
sudo /var/ossec/bin/wazuh-logtest
```

Paste this denied-flow sample:

```text
Jun 15 09:55:01 gns3 kernel: AURORA_HOST_GUARD denied IN=tap-aurora-mgmt OUT=eth1 SRC=10.255.191.11 DST=192.168.137.1 LEN=60 TOS=0x00 PREC=0x00 TTL=63 ID=12345 PROTO=TCP SPT=49152 DPT=22 WINDOW=64240 SYN
```

Expected rule:

```text
100103 Aurora: GNS3 VM guard denied lab-node access to protected host service.
```

Paste this normalized sample:

```json
{"aurora":{"control":"host-containment","action":"deny","src_zone":"lab","dst_zone":"host"},"source":{"ip":"10.255.191.11"},"destination":{"ip":"192.168.137.1","port":445}}
```

Expected rule:

```text
100101 Aurora: lab node attempted a protected host service.
```

Paste this RPKI exception sample:

```json
{"aurora":{"control":"host-containment","action":"allow","src_zone":"lab","dst_zone":"host"},"source":{"ip":"10.255.191.14"},"destination":{"ip":"192.168.137.1","port":3323}}
```

Expected rule:

```text
100102 Aurora: permitted RPKI-RTR exception from lab node to PC1.
```
