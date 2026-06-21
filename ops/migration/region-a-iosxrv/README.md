# Region A IOS-XRv migration

This directory contains the intended one-for-one translation from the deployed
Region A IOL configuration to IOS-XRv 6.1.3.

Use it with:

```text
ops/access/mops/2026-06-21-region-a-iol-to-iosxrv-migration.md
```

Rules:

- Preserve deployed state during the platform change.
- Confirm IOS-XRv interface names on the ADL canary before replacing any
  `<XR_*_IF>` placeholder.
- Elvis enters console configuration.
- Codex manages GNS3 plumbing and verifies state without using the console.
- Never commit secrets, password hashes, private keys, or full production
  configuration captures.
- VPNv4, VRFs, ROV, IPv6, and planned addressing are separate changes.

The current source state differs from the design:

- GEL currently uses Loopback0 `10.0.0.3/32`; the plan reserves `10.0.0.5/32`.
- ADL does not yet have Loopback0 `10.0.0.6/32`.
- MEL-PE1 to GEL and GEL to ADL core links are physically present but
  administratively unconfigured.

Do not correct those differences inside this migration.

