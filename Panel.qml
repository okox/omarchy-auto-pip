import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Auto picture-in-picture: shows whether it's on, click to switch it.
// The state lives in the auto-pip command (bin/auto-pip), which also calls
// `omarchy-shell -q okox.auto-pip refresh` when it's switched another way
// (a key binding, say), so the icon follows.
BarWidget {
  id: root
  moduleName: "okox.auto-pip"

  readonly property string toggleCmd: Quickshell.env("HOME") + "/.local/bin/auto-pip"
  property bool pipOn: true

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  ShellIpc {
    target: "okox.auto-pip"
    function refresh(): void { root.broadcast("refresh") }
  }

  Process {
    id: statusProc
    command: [root.toggleCmd, "status"]
    stdout: StdioCollector { onStreamFinished: root.pipOn = text.trim() !== "off" }
  }

  Process {
    id: toggleProc
    command: [root.toggleCmd, "toggle"]
    onExited: root.refresh()
  }

  Component.onCompleted: refresh()

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: Style.bar.statusSlot
    hasVisualContent: true
    tooltipText: root.pipOn
      ? "Auto picture-in-picture: on\nClick to switch off"
      : "Auto picture-in-picture: off\nClick to switch on"
    onPressed: if (!toggleProc.running) toggleProc.running = true

    // A screen with a small window in its bottom-right corner; dimmed and
    // struck through when off.
    iconComponent: Component {
      Item {
        id: icon
        readonly property color ink: button.foreground
        readonly property real s: Math.round(Style.bar.iconSize * 0.95)
        implicitWidth: s
        implicitHeight: s

        Item {
          anchors.centerIn: parent
          width: icon.s
          height: Math.round(icon.s * 0.78)
          opacity: root.pipOn ? 1 : 0.45

          Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: 2
            border.width: 1.5
            border.color: icon.ink
          }
          Rectangle {
            width: Math.round(parent.width * 0.46)
            height: Math.round(parent.height * 0.46)
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 3
            anchors.bottomMargin: 3
            radius: 1
            color: icon.ink
          }
        }
        Rectangle { // strike-through when off
          visible: !root.pipOn
          anchors.centerIn: parent
          width: Math.round(icon.s * 1.15)
          height: 1.5
          rotation: -40
          color: icon.ink
          antialiasing: true
        }
      }
    }
  }
}
