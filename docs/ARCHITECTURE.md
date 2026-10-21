# Architecture and implementation decision

## Source project audit

The inspected source is a JavaScript application, not Vite and not WebGL:

- React 18.2 with Create React App (`react-scripts` 5.0.1).
- React Router 7 for `/`, `/download`, and `/game` website routes.
- Electron 28 for the macOS tray application.
- Canvas 2D for every game graphic; there are no sprite-sheet gameplay assets.
- `requestAnimationFrame` for the game loop.
- Web Audio oscillators for flap, score, and collision sounds; there are no audio files.
- `localStorage` for the best score and top-five leaderboard.
- Space, Arrow Up, W, click, and touch are the browser controls.

Production web builds use `react-scripts build`; macOS packaging uses
`electron-builder --mac` after that build.

The gameplay itself makes no network request. The website shell is not fully
offline because `public/index.html` loads Google Fonts and the landing/download
routes link to Stripe and Dropbox. A static offline web build is technically
possible by selecting only the game route, bundling fonts, and removing those
links. That does not make it the best R36S runtime.

## Runtime options evaluated

### Browser/Electron

Rejected for the dedicated console. PortMaster documents that these handheld
Linux systems normally have no X11 or display manager and launch through
KMS/DRM or SDL2. Chromium/Electron would add large memory and startup costs and
would require a graphical stack that ArkOS deliberately does not use.

### Existing HTML5 runtime

Rejected as the primary path. PortMaster's public compatibility guidance lists
plain JavaScript games as unsupported; its newer Weston runtime can host some
X11-style software but is substantially heavier than needed for this Canvas 2D
game.

### Hand-written C++/SDL2

Technically strong but not necessary. It would duplicate a large amount of the
existing procedural drawing/game code and would require a separate ARM cross
toolchain. That adds porting risk without a performance need for this simple game.

### LÖVE 11.5 on SDL2

Selected. PortMaster publishes an ARM64 LÖVE runtime specifically for these
devices. It uses the device's native SDL/OpenGL ES/audio/controller stack, runs
without X11 or a browser, and lets the existing JavaScript Canvas logic be
translated nearly line-for-line to Lua. The runtime and all libraries are
bundled, so gameplay is entirely offline.

### Base operating system

Use the R36S-specific ArkOS multipanel image rather than inventing a kernel,
bootloader, or device tree. The current maintainer-linked image is
`ArkOS_R35S-R36S_v2.0_11072025_MultiPanel.img.xz`. The image retains the
R36S bootloader, kernel, panel files, input/audio drivers, and recovery tools.
The custom layer disables EmulationStation in the normal path and starts only
Pecker Tap.

Sources:

- https://github.com/AeolusUX/ArkOS-R3XS/releases
- https://portmaster.games/porting.html
- https://portmaster.games/packaging.html
- https://github.com/PortsMaster/PortMaster-GUI/tree/main/PortMaster/runtimes/love_11.5

## Browser fidelity

`game/main.lua` follows `src/landingpage.jsx`, which is the live browser game:

- A 720×540 landscape world rendered uniformly into the 640×480 LCD. It extends
  the browser game's 360×540 world sideways, so the display is completely filled
  without stretching the bird, text, pipes, ground, or vertical geometry.
- Ten layered procedural clouds, preserving the browser version's density,
  speed, size, and height ranges across the wider sky.
- The same eight sky palettes and one-second interpolation.
- 110 deterministically seeded stars, preserving the browser version's density,
  sizes, twinkle phases, and alpha curve across the wider sky.
- Clouds fade as stars become visible.
- Identical gravity, flap impulse, pipe sizes/gap curve/spawn curve, collision box,
  fixed 60 Hz timing, bird squash/stretch/blink/wing frames, and score sounds.
  Horizontal pipe speed is scaled only to compensate for the wider travel path,
  keeping the original time-to-first-pipe and cadence.
- Matching outlined pixel text, smooth horizontal pipe gradients, bird highlight,
  particle color sequence, and menu animation timing.
- An original offline chiptune soundtrack synthesized at startup: eight bars at
  150 BPM split into synchronized base, lead, and drive layers. The drive layer
  enters progressively at scores 3, 8, and 16; night, rain, and storms reshape
  the mix without restarting the seamless loop.
- A separately seeded quack scheduler adds a real female mallard “quack quack”
  every 10–22 seconds without consuming gameplay randomness. The compact PCM
  cue is bundled locally and credited in `game/assets/ATTRIBUTION.md`. On collision, the music
  ducks immediately beneath an original descending arcade defeat motif.
- A 52-second visual weather loop crossfades between clear skies, breeze, rain,
  storms with lightning, mist, and snow. Weather particles are deterministically
  seeded, remain cosmetic, and never consume gameplay randomness or alter flight.
- A separate deterministic scheduler places golden feathers every three to five
  pipes after the first pickup opportunity. Feathers sit near alternating gap
  edges, persist in `feathers.txt`, and unlock sunset, sky, and moon bird palettes
  at totals of 5, 15, and 30. They do not change score or pipe difficulty.
- The entire LCD is game scenery; there are no letterbox bars or side panels.

## Supervision and recovery

`peckertap.service` uses `Restart=on-failure`, a two-second delay, and a limit of
five starts per minute. Logs are available with `journalctl -u peckertap`.

The normal getty is conditional on `/boot/PECKERTAP_RECOVERY`; without that
marker there is no login prompt. With the marker present, Pecker Tap is skipped,
TTY1 and SSH are started, and maintenance is possible. The marker is on the FAT
boot partition so it can be created or removed from macOS.

## Known hardware risk

The inserted card contains `V5.txt`, indicating a Panel 5 history, but its active
DTB hashes do not match the stock `ScreenFiles/Panel 5` files. Its active kernel
and DTBs do match the downloaded multipanel base; its `boot.ini` does not. The
custom image therefore installs the exact `boot.ini` and active DTBs already
proven on this card, and also copies them to `BOOT/PeckerTap-Hardware-Backup`.
The complete original BOOT partition is preserved in `hardware-backup/BOOT`
with SHA-256 hashes. The initial dedicated image booted successfully on the
handheld; the new edge-to-edge layout still requires a physical display check.
