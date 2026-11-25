const assert = require("node:assert/strict")
const Capture = require("../Capture.js")

assert.equal(Capture.fmtBytes(154018144), "147 MB")
assert.equal(Capture.fmtBytes(2147483648), "2.0 GB")
assert.equal(Capture.friendlyClipName("NBA_2K27_2026-11-24_21-41-20.mp4"), "NBA 2K27")
assert.equal(Capture.friendlyClipName("screenrecording-2026-11-18_09-59-09.mp4"), "screenrecording")

const p = Capture.parseClipsPayload(JSON.stringify({
  clipsActive: true,
  clipSeconds: 30,
  recordAudio: "focused-app",
  clipsDir: "/tmp/Clips",
  items: [{ path: "/tmp/Clips/NBA_2K27_2026-11-24_21-41-20.mp4", name: "NBA_2K27_2026-11-24_21-41-20.mp4", kind: "clip", size: 1048576, mtime: 1000 }]
}))
assert.equal(p.clipsActive, true)
assert.equal(p.items[0].label, "NBA 2K27")
assert.equal(Capture.parseClipsPayload("{"), null)

console.log("PASS cornerstone.capture unit tests")
