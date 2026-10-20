# Build manifest

Built on 2026-10-20. These hashes identify the currently prepared artifacts.

| Artifact | SHA-256 |
|---|---|
| `dist/PeckerTap-R36S.img` | `cd8380895dfd68f74f6730449ea7faa74a840cee560517ea29460ba1bb1918cb` |
| `dist/peckertap-r36s-port.zip` | `7cf0207e5b702ed204381bf07af5f24224ec0ebe2d417a6ff6bd7b252ac15f3d` |
| `dist/peckertap-rootfs-overlay.tar.gz` | `8bb83fa749249faf61804b6652cc4d9c1798f4625d1702f60bd0fc51c340f6b2` |
| Packaged `peckertap.love` | `ebf11c7c3cb59fd4a0d11b3d8d4be62356b6a5a761bf778ffec3f06ef9b5f2bc` |
| Real mallard double-quack WAV | `f7cce19871470981e204406290af7dcbcbcf35e21919da3005f2b024542b2f66` |
| `dist/peckertap-r36s.png` | `fe49a1464307bcfebb48ebcaeda7e5836912c9de225365462951af30e307510f` |
| `dist/peckertap-r36s-night.png` | `e3e7112211b66499b01a82438b3be66073df3714282c28afcba528b6860c35d0` |
| ArkOS compressed base | `55721f501bc6f01043d51c217ffecbd3db203c9bbb33712568dad6ba9c4a5473` |
| ArkOS expanded base | `c3909660e8461a38be20e7baa9b7ef450de5c7d676b3e69efd253a357a8786d6` |

Mac-side verification completed:

- ArkOS XZ stream passed its CRC integrity test.
- Final image has the expected MBR, FAT32 BOOT, ext4 Linux, and NTFS EASYROMS partitions.
- Read-only `e2fsck -fn` completed with no filesystem errors.
- The embedded rootfs overlay is byte-identical to the built overlay artifact.
- Final `boot.ini` and active DTBs match the inserted card's hardware backup.
- Boot splash is a bottom-up 640×480, 24-bit Windows BMP.
- ARM runtime is an AArch64 ELF and every required dynamic library is present in ArkOS.
- Game/runtime scan found no network calls or remote asset references.
- Shell syntax, JSON metadata, required assets, controller database, service files,
  and ARM runtime checks passed `scripts/verify.sh`.
- Edge-to-edge day and night 640×480 renders passed visual inspection using
  official LÖVE 11.5; neither render contains side bars.
- The packaged `main.lua` is byte-identical to the verified 720×540 landscape
  source, and both nested ZIP archives passed integrity tests.
- The original “Skybound Peck” procedural soundtrack initializes successfully
  in the official LÖVE 11.5 runtime and begins with the boot splash.
- Forced audio-event testing reached both `event=quack` and `event=game_over`,
  exercising the real mallard double-quack and original descending defeat-jingle paths.

The previous portrait image successfully booted and ran on the user's R36S.
Not yet verified for this landscape revision: edge-to-edge physical LCD output,
controller behavior after reflash, audio routing/volume, sustained frame pacing,
and shutdown behavior.
