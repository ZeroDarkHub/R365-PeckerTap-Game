# Build manifest

Built on 2026-10-20. These hashes identify the currently prepared artifacts.

| Artifact | SHA-256 |
|---|---|
| `dist/PeckerTap-R36S.img` | `9544def516e59ec54fae7b5f1352d9db2cae449d731a8fcee7ed030143e4a68d` |
| `dist/peckertap-r36s-port.zip` | `cdff5b8f4803cf5dfb73bddba4ee2b32e89896782882d591a4ba46912a652d27` |
| `dist/peckertap-rootfs-overlay.tar.gz` | `47a7c5aeadaeb4175872de9df8191e38f5293d04c619b028406cec261c3ff7ce` |
| Packaged `peckertap.love` | `4fa912d2d7a4bdda417f358404370bb90d25f03231cadc305d3aec21ed0fe697` |
| Real mallard double-quack WAV | `f7cce19871470981e204406290af7dcbcbcf35e21919da3005f2b024542b2f66` |
| `dist/peckertap-r36s.png` | `fe49a1464307bcfebb48ebcaeda7e5836912c9de225365462951af30e307510f` |
| `dist/peckertap-r36s-night.png` | `e3e7112211b66499b01a82438b3be66073df3714282c28afcba528b6860c35d0` |
| `dist/peckertap-r36s-storm-feather.png` | `64197d1ec0dae093b6e95091accdc6da77344992afd757cd6b7210c22efcebe0` |
| `dist/peckertap-r36s-snow-pickup.png` | `b87b194fce8c8aee88ff8655200539643de38b5d22075b4723b97b490a23cf8b` |
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
- Forced feature testing rendered storm/rain and snow at 640×480, exercised the
  score-8 and score-16 music tiers, collected a feather, persisted its total,
  played the pickup sound, and unlocked the five-feather sunset bird palette.

The edge-to-edge landscape game and soundtrack have run successfully on the
user's R36S. Not yet verified on physical hardware for this feature revision:
weather visibility, layered-music balance, feather pickup/persistence, and the
new palette unlocks.
