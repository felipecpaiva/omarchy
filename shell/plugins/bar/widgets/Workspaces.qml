import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  // A bar surface exists per monitor, so each one has to answer for its own
  // screen. Reading Hyprland.focusedWorkspace instead makes every bar echo
  // whichever monitor holds focus, so switching workspaces on one screen visibly
  // moves the indicator on all the others.
  //
  // QsWindow does not attach to a loaded widget (Bar.qml reaches for the slot to
  // get at it), and the ProxiedWindow behind Window.window exposes no screen. Its
  // position does match the monitor it sits on, though, and that is enough.
  // Monitor x/y are logical while width/height are physical, hence the scale.
  readonly property var hyprMonitor: {
    var window = root.Window ? root.Window.window : null
    if (!window) return null

    var monitors = Hyprland.monitors.values
    for (var i = 0; i < monitors.length; i++) {
      var monitor = monitors[i]
      var scale = monitor.scale > 0 ? monitor.scale : 1
      var right = monitor.x + monitor.width / scale
      var bottom = monitor.y + monitor.height / scale
      if (window.x >= monitor.x && window.x < right && window.y >= monitor.y && window.y < bottom) {
        return monitor
      }
    }

    return null
  }

  readonly property string monitorName: hyprMonitor && hyprMonitor.name ? String(hyprMonitor.name) : ""

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function onThisMonitor(workspace) {
    // No monitor resolved (one screen, or the window is not up yet) means there
    // is nothing to divide, so everything counts as ours.
    if (root.monitorName === "") return true
    if (!workspace || !workspace.monitor || !workspace.monitor.name) return true
    return String(workspace.monitor.name) === root.monitorName
  }

  function isFirstMonitor() {
    if (!root.hyprMonitor) return true
    var monitors = Hyprland.monitors.values
    var lowest = null
    for (var i = 0; i < monitors.length; i++) {
      if (lowest === null || monitors[i].id < lowest.id) lowest = monitors[i]
    }
    return lowest === null || lowest === root.hyprMonitor
  }

  function workspaceIds() {
    var ids = []
    var elsewhere = ({})
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var workspace = values[i]
      var id = workspace.id
      if (id <= 0 || id > 10) continue

      if (root.onThisMonitor(workspace)) {
        if (ids.indexOf(id) === -1) ids.push(id)
      } else {
        elsewhere[id] = true
      }
    }

    // 1 to 5 stay visible as empty slots the way they always have, minus any that
    // currently live on another screen. Only the first monitor carries them: a
    // second screen is there to hold a couple of things, and padding it out with
    // empty slots that belong to the main screen is just noise. With one monitor
    // that monitor is the first one, so this is the old list unchanged.
    if (root.isFirstMonitor()) {
      for (var slot = 1; slot <= 5; slot++) {
        if (!elsewhere[slot] && ids.indexOf(slot) === -1) ids.push(slot)
      }
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: root.hyprMonitor && root.hyprMonitor.activeWorkspace
          ? root.hyprMonitor.activeWorkspace.id === modelData
          : (Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData)

        bar: root.bar
        text: focused ? "\uDB85\uDCFB" : (modelData === 10 ? "0" : String(modelData))
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }
      }
    }
  }
}
