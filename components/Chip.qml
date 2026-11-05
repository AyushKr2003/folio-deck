import QtQuick
import ".."

// A pill for sources and sorts: a pill when Hyprland rounds windows, square
// when it doesn't, like Omarchy's own toggles.
Rectangle {
  id: chip
  property string text: ""
  property string icon: ""
  property bool active: false
  signal clicked()
  implicitHeight: Tk.hChip
  implicitWidth: row.implicitWidth + Tk.s3 * 2
  radius: Tk.pill(height)
  color: active ? Tk.accent : hover.containsMouse ? Tk.surfaceHigher : Tk.surfaceHigh
  border.width: active ? 0 : 1
  border.color: Tk.outline
  Behavior on color { ColorAnimation { duration: Tk.fast } }
  Row {
    id: row
    anchors.centerIn: parent
    spacing: Tk.s1 + 2
    Icon { visible: chip.icon !== ""; name: chip.icon; size: Tk.iconSmall; filled: chip.active; color: chip.active ? Tk.onAccent : Tk.dim; anchors.verticalCenter: parent.verticalCenter }
    Label { visible: chip.text !== ""; text: chip.text; font.pixelSize: Tk.fsSmall; font.weight: chip.active ? Font.DemiBold : Font.Medium; color: chip.active ? Tk.onAccent : Tk.fg; anchors.verticalCenter: parent.verticalCenter }
  }
  MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
}
