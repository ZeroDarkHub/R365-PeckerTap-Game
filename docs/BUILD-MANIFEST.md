# Build manifest

Built on 2026-10-21. These hashes identify the currently prepared artifacts.

| Artifact | SHA-256 |
|---|---|
| `dist/PeckerTap-R36S.img` | `306933b2dda31a7d662083ae8c0c577b7168f3423ab69be1e3c8bbbcd8dd776b` |
| `dist/peckertap-r36s-port.zip` | `adb65d54caf88bcd78113c8831cee65a1cc7e513c5c99140920be0f35e9b242b` |
| `dist/peckertap-rootfs-overlay.tar.gz` | `b7b3f7a1fdce1758ca74b1d487699b453c252a6aa29976a4571f4a58b2c5c7bb` |
| Packaged `peckertap.love` | `5cb64191574f840db735a80cb7b1ce1660485a30d475e279d18a46f681c06192` |
| Real mallard double-quack WAV | `f7cce19871470981e204406290af7dcbcbcf35e21919da3005f2b024542b2f66` |
| `dist/peckertap-r36s.png` | `fe49a1464307bcfebb48ebcaeda7e5836912c9de225365462951af30e307510f` |
| `dist/peckertap-r36s-night.png` | `e3e7112211b66499b01a82438b3be66073df3714282c28afcba528b6860c35d0` |
| `dist/peckertap-r36s-storm-feather.png` | `64197d1ec0dae093b6e95091accdc6da77344992afd757cd6b7210c22efcebe0` |
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
- The redesigned boot splash and opening menu passed visual inspection at
  640×480, including the enlarged title and separated score/feather panels.
- The packaged `main.lua` is byte-identical to the verified 720×540 landscape
  source, and both nested ZIP archives passed integrity tests.
- The original “Skybound Peck” procedural soundtrack initializes successfully
  in the official LÖVE 11.5 runtime and begins with the boot splash.
- Forced audio-event testing reached both `event=quack` and `event=game_over`,
  exercising the real mallard double-quack and original descending defeat-jingle paths.
- Forced feature testing rendered storm/rain and mist at 640×480, exercised the
  score-8 and score-16 music tiers, collected a feather, persisted its total,
  played the pickup sound, and changed the bird from yellow to pink at 10.
- The detailed feather vane, barb lines, glow, and multi-axis floating motion
  passed 640×480 visual inspection; its animated hit position also passed a
  forced pickup and palette-unlock test.
- The opening feather total is now text-only and centered, and the 115-second
  clear/breeze/rain/storm/mist schedule passed source and preview verification;
  the removed snow override falls back to clear weather.
- The in-game feather counter now renders without a background panel, the
  game-over card omits feather totals, and the raised menu count passed
  dedicated 640×480 HUD, menu, and game-over visual checks.
- Yellow, pink, blue, green, purple, and black remain tied to the single saved
  totals 0, 10, 20, 30, 40, and 50. A forced 9→10 pickup wrote and verified two
  save copies, then a separate process relaunched at the opening screen with 10
  feathers and the pink bird. The parser now isolates LÖVE's data return value so
  its byte-count return can never be mistaken for `tonumber`'s optional base.
- Three pixel hearts passed 640×480 visual checks beside the HUD feather count.
  A forced first death retained pink and 10 feathers while removing one heart;
  a forced final-heart death wrote both save copies as zero, changed the bird to
  yellow, and relaunched at the opening screen with yellow and zero feathers.

The edge-to-edge landscape game and soundtrack have run successfully on the
user's R36S. Not yet verified on physical hardware for this feature revision:
weather visibility, layered-music balance, feather pickup/persistence, and the
new palette unlocks.
