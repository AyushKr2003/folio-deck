pragma ComponentBehavior: Bound
import QtQuick
import ".."

// The whole deck in one line: a segment per card in its primary colour
// (sorted by colour, a spectrum), a bracket round the cards in hand, ticks
// over the favourites and a dot under the one in use. Hover for a glimpse
// of any card; click or drag along it to go there.
Item {
  id: ribbon

  property var colors: []           // one per card ("" while unread)
  property var favourites: []       // indexes
  property real pos: 0
  property int span: 7
  property int activeIndex: -1
  property real u: 1
  property color accent: Tk.accent
  property color ink: Tk.fg
  property color surface: Tk.popupBg
  property var thumbs: []           // a picture per card, for the glimpse
  property var names: []
  signal jump(int index, bool instant)

  readonly property int count: colors.length
  readonly property real seg: width / Math.max(1, count)

  implicitHeight: 22 * u

  Rectangle {
    id: strip
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width; height: 6 * ribbon.u
    radius: Tk.rounded ? height / 2 : 0
    color: Tk.alpha(ribbon.ink, 0.1)
    clip: true
    Row {
      Repeater {
        model: ribbon.count
        Rectangle {
          required property int index
          width: ribbon.seg; height: strip.height
          color: ribbon.colors[index] || Tk.alpha(ribbon.ink, 0.12)
        }
      }
    }
  }

  // Favourites: a tick above.
  Repeater {
    model: ribbon.favourites
    Rectangle {
      required property var modelData
      x: (modelData + 0.5) * ribbon.seg - width / 2
      y: strip.y - 6 * ribbon.u
      width: Math.max(2, 3 * ribbon.u); height: 4 * ribbon.u; radius: width / 2
      color: "#ff5c7a"
    }
  }

  // The one in use: a dot below.
  Rectangle {
    visible: ribbon.activeIndex >= 0
    x: (ribbon.activeIndex + 0.5) * ribbon.seg - width / 2
    y: strip.y + strip.height + 3 * ribbon.u
    width: 4 * ribbon.u; height: width; radius: width / 2
    color: ribbon.ink
  }

  // The cards in hand.
  Rectangle {
    readonly property real a: Math.max(0, ribbon.pos - ribbon.span)
    readonly property real b: Math.min(ribbon.count - 1, ribbon.pos + ribbon.span)
    x: a * ribbon.seg - 2
    width: (b - a + 1) * ribbon.seg + 4
    y: strip.y - 4 * ribbon.u; height: strip.height + 8 * ribbon.u
    radius: Tk.rounded ? 4 * ribbon.u : 0
    color: "transparent"
    border.width: 1
    border.color: Tk.alpha(ribbon.ink, 0.75)
  }
  // The one in front.
  Rectangle {
    x: (ribbon.pos + 0.5) * ribbon.seg - width / 2
    y: strip.y - 6 * ribbon.u; height: strip.height + 12 * ribbon.u
    width: Math.max(2, 2.5 * ribbon.u)
    radius: width / 2
    color: ribbon.accent
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    anchors.topMargin: -6 * ribbon.u; anchors.bottomMargin: -6 * ribbon.u
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    readonly property int at: Math.max(0, Math.min(ribbon.count - 1, Math.floor(mouseX / ribbon.seg)))
    onClicked: ribbon.jump(at, false)
    onPositionChanged: if (pressed) ribbon.jump(at, true)
  }

  // A glimpse of the card under the pointer.
  Rectangle {
    visible: mouse.containsMouse && ribbon.count > 0
    x: Math.max(0, Math.min(ribbon.width - width, (mouse.at + 0.5) * ribbon.seg - width / 2))
    y: strip.y + 18 * ribbon.u
    width: 180 * ribbon.u; height: 132 * ribbon.u
    radius: Tk.rounded ? 12 * ribbon.u : 0
    color: ribbon.surface
    border.width: 1; border.color: Tk.alpha(ribbon.ink, 0.14)
    Rounded {
      anchors.fill: parent; anchors.margins: 6 * ribbon.u; anchors.bottomMargin: 28 * ribbon.u
      radius: Tk.rounded ? 8 * ribbon.u : 0
      Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        source: mouse.containsMouse && ribbon.thumbs[mouse.at] ? "file://" + ribbon.thumbs[mouse.at] : ""
        sourceSize.width: 340; sourceSize.height: 210
      }
    }
    Text {
      anchors.bottom: parent.bottom; anchors.bottomMargin: 7 * ribbon.u
      x: 8 * ribbon.u; width: parent.width - 16 * ribbon.u
      text: ribbon.names[mouse.at] || ""
      elide: Text.ElideRight
      color: ribbon.ink
      font.family: Tk.font; font.pixelSize: 11.5 * ribbon.u; font.weight: Font.DemiBold
      textFormat: Text.PlainText
    }
  }
}
