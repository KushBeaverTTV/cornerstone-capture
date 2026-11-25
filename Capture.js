// Pure formatting & parsing helpers for Cornerstone Capture.

function fmtBytes(bytes) {
  var n = Number(bytes) || 0
  if (n >= 1024 * 1024 * 1024) return (n / (1024 * 1024 * 1024)).toFixed(1) + " GB"
  if (n >= 1024 * 1024) return Math.round(n / (1024 * 1024)) + " MB"
  if (n >= 1024) return Math.round(n / 1024) + " KB"
  return n + " B"
}

function ago(mtime, nowSec) {
  var t = Number(mtime) || 0
  if (t <= 0) return ""
  var d = Math.max(0, Math.round((Number(nowSec) || Date.now() / 1000) - t))
  if (d < 60) return "just now"
  if (d < 3600) return Math.round(d / 60) + "m ago"
  if (d < 86400) return Math.round(d / 3600) + "h ago"
  return Math.round(d / 86400) + "d ago"
}

function friendlyClipName(name) {
  var s = String(name || "").replace(/\.(mp4|mkv|webm|mov)$/i, "")
  s = s.replace(/^chrome-[a-z]{32}-?_?/i, "WebApp ")
  s = s.replace(/_20\d{2}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}$/, "")
  s = s.replace(/-20\d{2}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}$/, "")
  s = s.replace(/_/g, " ").trim()
  return s || String(name || "Clip")
}

function parseClipsPayload(text) {
  var d
  try { d = JSON.parse(String(text || "")) } catch (e) { return null }
  if (!d || typeof d !== "object" || Array.isArray(d)) return null
  var items = Array.isArray(d.items) ? d.items.slice(0, 12).map(function(c) {
    return {
      path: String(c.path || ""),
      name: String(c.name || ""),
      label: friendlyClipName(c.name),
      kind: c.kind === "recording" ? "recording" : "clip",
      size: Number(c.size) || 0,
      mtime: Number(c.mtime) || 0
    }
  }) : []
  return {
    clipsActive: d.clipsActive === true,
    clipSeconds: Math.max(2, parseInt(d.clipSeconds, 10) || 30),
    recordAudio: String(d.recordAudio || "focused-app"),
    clipsDir: String(d.clipsDir || ""),
    items: items
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    fmtBytes: fmtBytes,
    ago: ago,
    friendlyClipName: friendlyClipName,
    parseClipsPayload: parseClipsPayload
  }
}
