import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Capture.js" as Capture

// Bar widget & clips shelf for Cornerstone Capture.
// Left click: open panel. Right click: save clip (Alt+S). Middle click: toggle record.
Panel {
  id: root
  moduleName: "cornerstone.capture"
  ipcTarget: "cornerstone-capture"
  manageIpc: false

  readonly property var service: bar && bar.shell ? bar.shell.serviceFor("cornerstone.capture") : null
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color muted: Qt.darker(foreground, 1.55)
  readonly property color hairline: Qt.darker(foreground, 2.4)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property var palette: ({})
  readonly property color okColor: palette.color2 || Color.accent

  FileView {
    id: paletteFile
    path: Color.currentThemePath + "/colors.toml"
    printErrors: false
    onLoaded: {
      var found = {}
      var re = /^\s*([A-Za-z0-9_]+)\s*=\s*"(#[0-9A-Fa-f]{6,8})"/gm
      var m
      while ((m = re.exec(String(text()))) !== null) found[m[1]] = m[2]
      root.palette = found
    }
  }
  Connections {
    target: Color
    function onBackgroundChanged() { paletteFile.reload() }
    function onAccentChanged() { paletteFile.reload() }
  }

  readonly property bool recording: service ? service.recording : false
  readonly property int elapsed: service ? service.elapsed : 0
  readonly property string backend: service ? service.backend : "gpu-screen-recorder"
  readonly property bool replaySupported: service ? service.replaySupported : true
  readonly property bool clipsActive: service ? service.clipsActive : false
  readonly property int clipSeconds: service ? service.clipSeconds : 30
  readonly property string recordAudio: service ? service.recordAudio : "focused-app"
  readonly property var recentClips: service ? service.recentClips : []
  readonly property real nowSec: service ? service.nowSec : Date.now() / 1000

  readonly property string barTooltip: recording
    ? "Recording · " + (service ? service.clock(elapsed) : "0:00")
    : (!replaySupported
        ? "Capture · " + backend + " (middle-click to record)"
        : (clipsActive ? "Capture · " + clipSeconds + "s replay buffer armed" : "Capture · Replay buffer off"))

  onOpenedChanged: if (opened && service) { service.refresh(); service.refreshClips() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    horizontalMargin: 5
    fixedWidth: vertical ? -1 : (root.recording ? Math.max(Style.bar.iconSlot, pill.implicitWidth + scaledHorizontalMargin * 2) : Style.bar.iconSlot)
    fixedHeight: vertical ? Math.max(Style.bar.iconSlot, pill.implicitHeight + Style.space(6)) : -1
    tooltipText: root.opened ? "" : root.barTooltip
    onPressed: function(code) {
      if (code === Qt.RightButton && root.service) root.service.saveClip()
      else if (code === Qt.MiddleButton && root.service) root.service.toggleRecord()
      else root.toggle()
    }

    Row {
      id: pill
      anchors.centerIn: parent
      scale: button.pressScale
      spacing: Style.space(4)
      Item {
        width: Style.space(18); height: Style.space(18)
        anchors.verticalCenter: parent.verticalCenter
        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: root.recording ? "󰑊" : "󰕧"
          color: root.recording ? Color.urgent : (root.clipsActive ? root.foreground : root.muted)
          font.family: root.fontFamily
          font.pixelSize: Style.bar.iconFont
          renderType: Text.NativeRendering
        }
        Rectangle {
          visible: !root.recording && root.clipsActive
          width: 5; height: 5; radius: 2.5
          anchors.right: parent.right
          anchors.top: parent.top
          color: root.okColor
        }
      }
      Text {
        visible: root.recording
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: root.service ? root.service.clock(root.elapsed) : ""
        color: Color.urgent
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        font.features: { "tnum": 1 }
        renderType: Text.NativeRendering
      }
    }
  }

  component ActionBtn: Rectangle {
    id: btn
    property string label: ""
    property color tint: root.foreground
    property real fill: 0.12
    property bool enabledBtn: true
    signal activated()
    height: Style.space(30)
    radius: Style.space(6)
    opacity: enabledBtn ? 1 : 0.45
    color: Qt.rgba(tint.r, tint.g, tint.b, enabledBtn && a.containsMouse ? fill + 0.1 : fill)
    Behavior on color { ColorAnimation { duration: Style.duration(120) } }
    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: btn.label
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: fill >= 0.2
    }
    MouseArea {
      id: a
      anchors.fill: parent
      hoverEnabled: true
      enabled: btn.enabledBtn
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: btn.activated()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(580))

    content: PanelKeyCatcher {
      anchors.fill: parent
      implicitHeight: column.implicitHeight
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (!root.service) return
        if (t === "s" || t === "S") { root.service.saveClip(); root.close() }
        else if (t === "r" || t === "R") { root.service.toggleRecord(); root.close() }
        else if (t === "b" || t === "B") root.service.toggleClipsBuffer()
      }
      clip: true

      Column {
        id: column
        anchors.fill: parent
        spacing: Style.space(10)

        // Header
        Item {
          width: parent.width
          height: titleCol.implicitHeight
          Column {
            id: titleCol
            spacing: Style.space(2)
            Text {
              textFormat: Text.PlainText
              text: "Cornerstone Capture"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }
            Text {
              textFormat: Text.PlainText
              text: (root.recording ? "Recording " + (root.service ? root.service.clock(root.elapsed) : "")
                     : (!root.replaySupported ? "Ready · " + root.backend
                        : (root.clipsActive ? "Replay buffer armed (" + root.clipSeconds + "s)" : "Replay buffer off")))
                    + " · audio: " + root.recordAudio
              color: root.recording ? Color.urgent : root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        // Primary controls row
        Row {
          width: parent.width
          spacing: Style.space(8)

          ActionBtn {
            width: (parent.width - Style.space(8)) / 2
            label: root.recording ? "■  Stop Recording" : "●  Record (Alt+PrtSc)"
            tint: root.recording ? Color.urgent : root.foreground
            fill: root.recording ? 0.35 : 0.14
            onActivated: { if (root.service) root.service.toggleRecord(); root.close() }
          }

          ActionBtn {
            width: (parent.width - Style.space(8)) / 2
            label: "󰕧  Save " + root.clipSeconds + "s Clip"
            tint: Color.accent
            fill: 0.24
            enabledBtn: root.clipsActive
            onActivated: { if (root.service) root.service.saveClip(); root.close() }
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(8)

          ActionBtn {
            width: (parent.width - Style.space(8)) * 0.62
            label: root.clipsActive ? "Replay Buffer: ON" : "Replay Buffer: OFF"
            tint: root.clipsActive ? root.okColor : root.foreground
            fill: root.clipsActive ? 0.18 : 0.1
            onActivated: if (root.service) root.service.toggleClipsBuffer()
          }

          ActionBtn {
            width: (parent.width - Style.space(8)) * 0.38
            label: "Settings"
            onActivated: { if (root.service) root.service.openSettings(); root.close() }
          }
        }

        Rectangle { width: parent.width; height: 1; color: root.hairline }

        Item {
          width: parent.width
          height: recTitle.implicitHeight
          Text {
            id: recTitle
            anchors.left: parent.left
            textFormat: Text.PlainText
            text: "Recent clips & recordings"
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
          Text {
            anchors.right: parent.right
            textFormat: Text.PlainText
            text: "Open folder ↗"
            color: folderMouse.containsMouse ? Color.accent : root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            MouseArea {
              id: folderMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: { if (root.service) root.service.openClipsFolder(); root.close() }
            }
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(5)

          Text {
            visible: root.recentClips.length === 0
            textFormat: Text.PlainText
            text: root.replaySupported
              ? "No clips yet — press Alt+S to save the last " + root.clipSeconds + "s"
              : "No recordings yet — click Record to capture via " + root.backend
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Repeater {
            model: root.recentClips.slice(0, 6)
            Rectangle {
              required property var modelData
              width: parent.width
              height: Style.space(36)
              radius: Style.space(6)
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b,
                             clipMouse.containsMouse ? 0.12 : 0.05)
              Behavior on color { ColorAnimation { duration: Style.duration(120) } }

              MouseArea {
                id: clipMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { if (root.service) root.service.playClip(modelData.path); root.close() }
              }

              Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Style.space(10)
                anchors.right: clipBtns.left
                anchors.rightMargin: Style.space(6)
                spacing: 1
                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: modelData.label
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  elide: Text.ElideRight
                }
                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: (modelData.kind === "recording" ? "Recording" : "Clip")
                        + " · " + Capture.fmtBytes(modelData.size)
                        + " · " + Capture.ago(modelData.mtime, root.nowSec)
                  color: root.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }

              Row {
                id: clipBtns
                anchors.right: parent.right
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)

                Rectangle {
                  width: Style.space(24); height: Style.space(24); radius: Style.space(5)
                  color: copyA.containsMouse ? Util.alpha(Color.accent, 0.25) : "transparent"
                  Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: "󰆏"
                    color: copyA.containsMouse ? Color.accent : root.muted
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                  MouseArea {
                    id: copyA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.service) root.service.copyClipPath(modelData.path)
                  }
                }

                Rectangle {
                  width: Style.space(24); height: Style.space(24); radius: Style.space(5)
                  color: delA.containsMouse ? Util.alpha(Color.urgent, 0.25) : "transparent"
                  Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: "󰅖"
                    color: delA.containsMouse ? Color.urgent : root.muted
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                  MouseArea {
                    id: delA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.service) root.service.deleteClip(modelData.path)
                  }
                }
              }
            }
          }
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          text: "Right-click = save clip · middle-click = record · s clip · r record · b buffer"
          color: root.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
