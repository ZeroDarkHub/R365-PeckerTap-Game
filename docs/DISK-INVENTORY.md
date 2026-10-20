# Disk inventory — read-only observation

Observed before any destructive action:

| Identifier | Capacity | Device | Protocol | Removable | Role |
|---|---:|---|---|---|---|
| `/dev/disk0` | 500.3 GB | APPLE SSD AP0512R | Apple Fabric | Fixed | Internal startup storage; never target |
| `/dev/disk4` | 128.0 GB | Built In SDXC Reader | Secure Digital | Removable | Candidate R36S microSD |
| `/dev/disk5` | 1.0 TB | Rugged USB-C / LaCie | USB | Fixed | External user drive; never target |

The candidate card currently has:

- `disk4s1`: 117.4 MB FAT32 `BOOT`
- `disk4s2`: 11.4 GB Linux root
- `disk4s3`: 116.5 GB NTFS `EASYROMS`

This inventory is time-sensitive. Device numbers can change after eject/reinsert.
Run `diskutil list` and `diskutil info` again immediately before flashing.

No disk has been erased or written during preparation.
