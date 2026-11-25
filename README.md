# Cornerstone Capture

Recording indicator, replay-buffer controller, and recent-clips shelf for the Omarchy status bar.

- **Bar icon**: compact camera glyph with a green dot when the replay buffer is armed; expands into a live red `󰑊 M:SS` timer while recording (plus a secondary-monitor recording pill).
- **Clicks**: left-click opens the clips drawer, right-click saves a replay clip, middle-click toggles screen recording.
- **Clips drawer**: Save Clip (`Alt+S`), Start/Stop Recording, Replay Buffer toggle, and the 10 most recent clips/recordings with one-click play, copy path, and open folder.

## Tests

```bash
node tests/run.js
```
