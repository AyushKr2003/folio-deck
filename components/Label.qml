import QtQuick
import ".."

// Plain text only (file names are untrusted), in the Omarchy font.
Text {
  color: Tk.fg
  textFormat: Text.PlainText
  font.family: Tk.font
  font.pixelSize: Tk.fsBody
  elide: Text.ElideRight
  verticalAlignment: Text.AlignVCenter
}
