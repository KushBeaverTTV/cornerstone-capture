import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "Capture.js" as Capture

// Single session-wide service for Cornerstone Capture:
//  - Renders the themed recording pill on your other monitor while recording
//  - Tracks the 30s replay clip buffer and recent clips/recordings for Panel.qml
//  - Owns the `cornerstone-capture` IPC target
Item {
  id: root

  property var shell: null
  readonly property string pluginId: "cornerstone.capture"
  readonly property string cli: Quickshell.env("HOME") + "/.local/bin/cornerstone-capture"
  readonly property string clipsProbe: Qt.resolvedUrl("bin/list-clips.py").toString().replace(/^file:\/\//, "")

  property bool recording: false
  property bool stopping: false
  property int baseElapsed: 0
  property double syncedAt: 0
  property int elapsed: 0
  property string overlayMonitor: ""
  property bool refreshPending: false

  // Replay buffer & clips shelf state
  property string backend: "gpu-screen-recorder"
  property bool replaySupported: true
  property bool clipsActive: false
  property int clipSeconds: 30
  property string recordAudio: "focused-app"
  property string clipsDir: Quickshell.env("HOME") + "/Videos/Clips"
  property var recentClips: []
  property real nowSec: Date.now() / 1000

  function refresh() {
    if (statusProc.running) {
      root.refreshPending = true
      return
    }
    root.refreshPending = false
    statusProc.running = true
  }

  function refreshClips() {
    nowSec = Date.now() / 1000
    if (!clipsProc.running) clipsProc.running = true
  }

  function apply(text) {
    var s
    try { s = JSON.parse(String(text || "")) } catch (e) { return }
    if (!s || typeof s !== "object") return
    root.recording = s.recording === true
    root.baseElapsed = Math.max(0, Math.floor(Number(s.elapsed) || 0))
    root.syncedAt = Date.now()
    root.elapsed = root.baseElapsed
    root.overlayMonitor = String(s.overlay || "").slice(0, 64)
    if (!root.recording) root.stopping = false
  }

  function applyClips(text) {
    var d = Capture.parseClipsPayload(text)
    if (!d) return
    backend = d.backend
    replaySupported = d.replaySupported
    clipsActive = d.clipsActive
    clipSeconds = d.clipSeconds
    recordAudio = d.recordAudio
    if (d.clipsDir) clipsDir = d.clipsDir
    recentClips = d.items
    nowSec = Date.now() / 1000
  }

  function toggleRecord() {
    Quickshell.execDetached([root.cli, "record", "toggle"])
    refreshSoon.restart()
  }

  function stop() {
    if (root.stopping) return
    root.stopping = true
    Quickshell.execDetached([root.cli, "record", "stop"])
    refreshSoon.restart()
  }

  function saveClip() {
    Quickshell.execDetached([root.cli, "clip", "save"])
    Quickshell.execDetached(["omarchy-shell", "dynamic-island", "toast",
      "Saving clip", "Last " + clipSeconds + "s from replay buffer", "󰕧", "accent"])
    clipsSoon.restart()
  }

  function toggleClipsBuffer() {
    Quickshell.execDetached([root.cli, "clips", "toggle"])
    clipsSoon.restart()
  }

  function openSettings() {
    Quickshell.execDetached([root.cli, "settings"])
  }

  function openClipsFolder() {
    Quickshell.execDetached(["xdg-open", clipsDir])
  }

  function playClip(path) {
    if (!path) return
    Quickshell.execDetached(["xdg-open", String(path)])
  }

  function copyClipPath(path) {
    if (!path) return
    Quickshell.execDetached(["sh", "-c", 'printf "file://%s\n" "$1" | wl-copy --type text/uri-list', "sh", String(path)])
    Quickshell.execDetached(["omarchy-shell", "dynamic-island", "toast",
      "Clip copied", Capture.friendlyClipName(String(path).split("/").pop()), "󰆏", "green"])
  }

  function deleteClip(path) {
    var p = String(path || "")
    var allowedBase = Quickshell.env("HOME") + "/Videos/"
    if (p.indexOf(allowedBase) !== 0 || p.indexOf("..") !== -1) return
    Quickshell.execDetached(["rm", "-f", p])
    clipsSoon.restart()
  }

  function clock(seconds) {
    var h = Math.floor(seconds / 3600)
    var m = Math.floor((seconds % 3600) / 60)
    var s = seconds % 60
    var ss = (s < 10 ? "0" : "") + s
    if (h > 0) return h + ":" + (m < 10 ? "0" : "") + m + ":" + ss
    return m + ":" + ss
  }

  Component.onCompleted: {
    refresh()
    refreshClips()
  }

  Process {
    id: statusProc
    command: [root.cli, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.apply(text)
    }
    onExited: function() {
      if (root.refreshPending) Qt.callLater(root.refresh)
    }
  }

  Process {
    id: clipsProc
    command: ["python3", root.clipsProbe]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyClips(text)
    }
  }

  // Idle watch: exit code only, supports both gpu-screen-recorder and wf-recorder.
  Process {
    id: watchProc
    command: ["pgrep", "-x", "gpu-screen-reco|wf-recorder"]
    onExited: function(exitCode) {
      if ((exitCode === 0) !== root.recording) {
        root.refresh()
        root.refreshClips()
      }
    }
  }

  Timer {
    interval: 5000
    repeat: true
    running: !root.recording
    onTriggered: if (!watchProc.running) watchProc.running = true
  }

  // While recording: tick the clock every second, resync every five.
  Timer {
    interval: 1000
    repeat: true
    running: root.recording
    onTriggered: root.elapsed = root.baseElapsed + Math.floor((Date.now() - root.syncedAt) / 1000)
  }

  Timer {
    interval: 5000
    repeat: true
    running: root.recording
    onTriggered: root.refresh()
  }

  Timer {
    id: refreshSoon
    interval: 700
    onTriggered: { root.refresh(); root.refreshClips() }
  }

  Timer {
    id: clipsSoon
    interval: 1400
    onTriggered: root.refreshClips()
  }

  ShellIpc {
    target: "cornerstone-capture"

    function toggle(): string { if (root.shell) root.shell.toggle(root.pluginId); return "ok" }
    function refresh(): string { root.refresh(); root.refreshClips(); return "ok" }
    function stop(): string { root.stop(); return "ok" }
    function clip(): string { root.saveClip(); return "ok" }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: surface
      required property var modelData
      screen: modelData

      readonly property bool here: root.recording
        && (root.overlayMonitor === "" ? modelData === Quickshell.screens[0] : String(modelData.name) === root.overlayMonitor)

      visible: here
      color: "transparent"

      WlrLayershell.namespace: "cornerstone-capture"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Normal

      anchors { top: true; left: true }
      margins {
        top: Style.space(6)
        left: Style.space(6)
      }

      implicitWidth: pill.width
      implicitHeight: pill.height

      Rectangle {
        id: pill
        width: row.implicitWidth + Style.space(8) * 2 - Style.space(4)
        height: Math.max(Style.space(24), stopButton.height + Style.space(4) * 2)
        radius: Style.cornerRadius
        color: Util.alpha(Color.background, 0.94)
        border.width: Math.max(1, Style.normalBorderWidth)
        border.color: Util.alpha(Color.foreground, 0.22)

        opacity: surface.here ? 1 : 0
        scale: surface.here ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
        Behavior on scale {
          NumberAnimation { duration: Style.duration(180); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
        }

        Row {
          id: row
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.leftMargin: Style.space(8)
          spacing: Style.space(7)

          Rectangle {
            id: dot
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(8)
            height: width
            radius: width / 2
            color: root.stopping ? Color.muted : Color.urgent

            SequentialAnimation on opacity {
              running: surface.here && !root.stopping && Style.duration(1000) > 0
              loops: Animation.Infinite
              NumberAnimation { from: 1; to: 0.35; duration: 900; easing.type: Easing.Linear }
              NumberAnimation { from: 0.35; to: 1; duration: 900; easing.type: Easing.Linear }
              onStopped: dot.opacity = 1
            }
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: root.stopping ? "Saving" : root.clock(root.elapsed)
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.features: { "tnum": 1 }
          }

          Rectangle {
            id: stopButton
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(18)
            height: width
            radius: Style.cornerRadius
            color: stopArea.pressed ? Style.pressedFill : (stopArea.containsMouse ? Style.hoverFill : "transparent")
            border.width: stopArea.containsMouse ? Style.hoverBorderWidth : 0
            border.color: Style.hoverBorderColor

            Rectangle {
              anchors.centerIn: parent
              width: Style.space(8)
              height: width
              radius: Math.min(Style.cornerRadius, 2)
              color: root.stopping ? Color.muted : Color.foreground
            }

            MouseArea {
              id: stopArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              enabled: !root.stopping
              onClicked: root.stop()
            }
          }
        }
      }
    }
  }
}
