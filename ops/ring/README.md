# Aurora lab edge ring

This directory is the placeholder for the ADR-004 data-plane ring:

```text
pc1-edge ---- pc2-edge ---- do-edge ---- oci-edge ---- pc1-edge
```

The host OSes remain outside the routed lab. Only virtual edge routers participate in the ring.

`ring-ebgp.example.conf` is a vendor-neutral policy sketch. Convert it into FRR, IOS, IOS-XE, IOS-XR, Junos, or cRPD syntax when the ring edge platform is chosen.
