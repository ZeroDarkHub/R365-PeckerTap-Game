# R36S physical test checklist

Do not mark a test passed without observing it on the handheld.

1. Initial provisioning completes its expected automatic restarts; the next and
   subsequent boots reach Pecker Tap without a login, terminal, desktop, or launcher.
2. Splash and game are upright, sharp, and fill all 640×480 pixels with scenery;
   no dark side bars are visible.
3. Day, dusk, star field, night, dawn, and sunrise palettes render without artifacts.
4. A/B/X/Y, D-pad, shoulders, Start, and analog-up respond on the first press.
5. Flap-to-motion latency feels immediate and frame pacing stays consistent.
6. Flap, score, real quack, feather pickup, collision, and defeat sounds play cleanly.
7. The soundtrack gains energy at scores 3, 8, and 16, then softens at night and in storms.
8. Clear, breeze, rain, storm/lightning, and mist remain readable through their
   longer phases and smooth three-second transitions.
9. Golden feathers appear near pipe-gap edges and can be collected.
10. Best score and feather total persist across a reboot.
11. The HUD shows the persistent feather total; bird colors switch to pink at
    10, blue at 20, green at 30, purple at 40, and black at 50, then stay black.
12. Five intentional crash tests do not create an endless restart loop.
13. Hold Select + Start for two seconds and verify clean shutdown.
14. Create the BOOT recovery marker and verify the game is skipped.
15. Remove the marker and verify normal direct boot resumes.

If anything fails, capture:

- A photo/video of the display.
- `journalctl -u peckertap -b` from recovery.
- `cat /proc/device-tree/model`.
- `cat /sys/class/graphics/fb0/virtual_size`.
- `evtest` output for each physical button.
- `aplay -l` and `amixer` output for audio problems.
