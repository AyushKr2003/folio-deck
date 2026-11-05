import QtQuick
import ".."

// A square-ish icon button on a soft plate.
Rectangle {
  id: b
  property string icon: ""
  property color tint: Tk.dim
  property bool filled: false
  signal clicked()
  implicitWidth: Tk.px(40)
  implicitHeight: Tk.px(40)
  radius: Tk.corner(width, height)
  color: mouse.containsMouse ? Tk.surfaceHigher : Tk.alpha(Tk.popupBg, 0.88)
  border.width: 1
  border.color: Tk.outline
  Icon { anchors.centerIn: parent; name: b.icon; color: b.tint; filled: b.filled }
  MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
}
