import QtQuick
import ".."

// A Material Symbols Rounded glyph by name.
Text {
  property string name: ""
  property real size: Tk.icon
  property bool filled: false
  text: name
  color: Tk.fg
  textFormat: Text.PlainText
  font.family: Tk.icons
  font.pixelSize: Math.round(size)
  font.variableAxes: ({ "FILL": filled ? 1 : 0, "wght": 450, "opsz": 24 })
  horizontalAlignment: Text.AlignHCenter
  verticalAlignment: Text.AlignVCenter
}
