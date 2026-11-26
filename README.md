# Cornerstone Capture

Multi-device recording indicator, replay-buffer controller, and recent-clips shelf for the Omarchy status bar.

- **Multi-backend**: supports `gpu-screen-recorder` + background replay buffer on AMD/NVIDIA/Intel desktops, and automatically adapts to `wf-recorder` (via `omarchy-capture-screenrecording`) on Apple Silicon and laptops without replay-buffer support.
- **Bar icon**: compact camera glyph with a green dot when the replay buffer is armed; expands into a live red `󰑊 M:SS` timer while recording (plus a secondary-monitor recording pill on multi-monitor setups).
- **Clicks**: left-click opens the drawer; right-click saves a replay clip (or toggles recording when replay buffer isn't available); middle-click toggles screen recording.
- **Drawer**: Start/Stop Recording, Save Clip (`Alt+S`) & Replay Buffer toggle (when supported), plus the 10 most recent clips/recordings with one-click play, copy path, and open folder.

## Tests

```bash
node tests/run.js
```
