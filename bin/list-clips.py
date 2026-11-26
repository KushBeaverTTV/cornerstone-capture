#!/usr/bin/env python3
"""Returns JSON with replay-buffer status, capture backend, settings, and recent clips/recordings."""
import glob
import json
import os
import platform
import re
import shutil
import subprocess

HOME = os.path.expanduser("~")
CONFIG = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.join(HOME, ".config"), "cornerstone-capture", "config")
VIDEO_EXTS = (".mp4", ".mkv", ".webm", ".mov")
UNIT_DIRS = (
    os.path.join(HOME, ".config/systemd/user"),
    "/etc/systemd/user",
    "/usr/lib/systemd/user",
)


def read_config():
    cfg = {"CLIP_SECONDS": "30", "RECORD_AUDIO": "focused-app", "CLIP_DIR": "", "RECORD_DIR": ""}
    try:
        with open(CONFIG) as f:
            for line in f:
                line = line.split("#", 1)[0].strip()
                m = re.match(r"^([A-Z_]+)\s*=\s*(.*)$", line)
                if m and m.group(1) in cfg:
                    cfg[m.group(1)] = m.group(2).strip().strip('"')
    except Exception:
        pass
    return cfg


def is_apple_silicon():
    if platform.machine() == "aarch64":
        for p in sorted(glob.glob("/sys/class/drm/card*/device/uevent")):
            try:
                with open(p) as f:
                    txt = f.read()
                if "DRIVER=asahi" in txt or "DRIVER=apple-drm" in txt:
                    return True
            except Exception:
                pass
    return False


def has_clips_service():
    return any(os.path.exists(os.path.join(d, "cornerstone-clips.service")) for d in UNIT_DIRS)


def clips_active():
    try:
        r = subprocess.run(
            ["systemctl", "--user", "is-active", "cornerstone-clips.service"],
            capture_output=True, text=True, timeout=1.5
        )
        return r.stdout.strip() == "active"
    except Exception:
        return False


def scan_dir(path, kind):
    out = []
    try:
        for entry in os.scandir(path):
            if not entry.is_file():
                continue
            if not entry.name.lower().endswith(VIDEO_EXTS):
                continue
            st = entry.stat()
            out.append({
                "path": entry.path,
                "name": entry.name,
                "kind": kind,
                "size": st.st_size,
                "mtime": int(st.st_mtime),
            })
    except Exception:
        pass
    return out


def main():
    cfg = read_config()
    rec_dir = os.path.expanduser(cfg["RECORD_DIR"] or "~/Videos")
    clips_dir = os.path.expanduser(cfg["CLIP_DIR"] or os.path.join(rec_dir, "Clips"))
    apple = is_apple_silicon()
    gsr_ok = bool(shutil.which("gpu-screen-recorder")) and not apple
    backend = "gpu-screen-recorder" if gsr_ok else ("wf-recorder" if shutil.which("wf-recorder") else "omarchy")
    replay_supported = gsr_ok and has_clips_service()
    items = scan_dir(clips_dir, "clip") + scan_dir(rec_dir, "recording")
    items.sort(key=lambda x: -x["mtime"])
    print(json.dumps({
        "backend": backend,
        "replaySupported": replay_supported,
        "clipsActive": clips_active() if replay_supported else False,
        "clipSeconds": int(cfg["CLIP_SECONDS"]) if cfg["CLIP_SECONDS"].isdigit() else 30,
        "recordAudio": cfg["RECORD_AUDIO"] or "focused-app",
        "clipsDir": clips_dir,
        "items": items[:10],
    }))


if __name__ == "__main__":
    main()
