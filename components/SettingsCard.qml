pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import ".."

// The deck's settings (the gear in its head): your own wallpaper folder (the
// "Folder" source), applied on Enter once it's found; and whether a card you
// set grows into the wallpaper or is set straight away, the deck staying
// open for more.
Rectangle {
  id: card

  property real u: 1
  property color surface: Tk.popupBg
  property color ink: Tk.fg
  property color muted: Tk.dim
  property color accent: Tk.accent
  property color accentInk: Tk.onAccent
  signal done()

  function reset() { field.text = Store.get("folder"); note.text = ""; field.forceActiveFocus(); field.selectAll() }

  width: 380 * u
  height: col.implicitHeight + 32 * u
  radius: Tk.rounded ? 18 * u : 0
  color: Tk.alpha(surface, 0.94)
  border.width: 1
  border.color: Tk.alpha(ink, 0.12)

  // Eats clicks, so they don't reach the deck under it.
  MouseArea { anchors.fill: parent }

  Column {
    id: col
    x: 16 * card.u; y: 16 * card.u
    width: parent.width - 32 * card.u
    spacing: 10 * card.u

    Text { text: "Settings"; color: card.ink; font.family: Tk.font; font.pixelSize: 15 * card.u; font.weight: Font.Bold; textFormat: Text.PlainText }

    Text { text: "Your wallpaper folder"; color: card.muted; font.family: Tk.font; font.pixelSize: 11.5 * card.u; textFormat: Text.PlainText }
    Rectangle {
      width: parent.width; height: 36 * card.u
      radius: Tk.rounded ? 10 * card.u : 0
      color: Tk.alpha(card.ink, 0.06)
      border.width: 1
      border.color: field.activeFocus ? card.accent : Tk.alpha(card.ink, 0.12)
      TextInput {
        id: field
        anchors.fill: parent; anchors.leftMargin: 10 * card.u; anchors.rightMargin: 10 * card.u
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: card.ink
        selectionColor: card.accent
        selectedTextColor: card.accentInk
        font.family: Tk.font; font.pixelSize: 12.5 * card.u
        onAccepted: { check.command = ["bash", "-c", "d=${1/#\\~/$HOME}; [[ -d $d ]] && realpath \"$d\"", "_", text]; check.running = true }
        Keys.onEscapePressed: card.done()
      }
    }
    Text {
      id: note
      visible: text !== ""
      width: parent.width
      wrapMode: Text.Wrap
      color: card.muted
      font.family: Tk.font; font.pixelSize: 11 * card.u
      textFormat: Text.PlainText
    }

    Item { width: 1; height: 2 * card.u }

    Item {
      width: parent.width; height: 32 * card.u
      Column {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 60 * card.u
        Text { text: "Grow into the wallpaper"; color: card.ink; font.family: Tk.font; font.pixelSize: 12.5 * card.u; font.weight: Font.DemiBold; textFormat: Text.PlainText }
        Text { width: parent.width; text: "Off: set it at once and stay open"; color: card.muted; elide: Text.ElideRight; font.family: Tk.font; font.pixelSize: 11 * card.u; textFormat: Text.PlainText }
      }
      Rectangle {
        id: sw
        readonly property bool on: Store.get("animateChoice")
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        width: 44 * card.u; height: 24 * card.u
        radius: Tk.rounded ? height / 2 : 0
        color: on ? card.accent : Tk.alpha(card.ink, 0.16)
        Behavior on color { ColorAnimation { duration: Tk.fast } }
        Rectangle {
          width: parent.height - 6 * card.u; height: width
          radius: Tk.rounded ? width / 2 : 0
          y: 3 * card.u
          x: sw.on ? parent.width - width - 3 * card.u : 3 * card.u
          color: sw.on ? card.accentInk : card.ink
          Behavior on x { NumberAnimation { duration: Tk.fast; easing.type: Easing.OutCubic } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Store.set("animateChoice", !sw.on) }
      }
    }
  }

  Process {
    id: check
    stdout: StdioCollector {
      onStreamFinished: {
        var d = String(text).trim()
        if (d) { Store.set("folder", d); field.text = d; note.text = "Saved. The Folder source now lists " + d + "." }
        else note.text = "No folder there."
      }
    }
  }
}
