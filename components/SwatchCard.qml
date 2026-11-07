pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import ".."
import "../core/Palette.js" as Palette

// One wallpaper (or theme) as a paint-chip card, dressed in the colours it
// would bring: the card is its palette's surface, the text its ink, the edge
// lit with its accent as the card comes to the front. Under the picture, the
// five chips with their hex codes; then the name and a line about the file.
Item {
  id: card

  // Pixels per design pixel (the deck scales with the screen).
  property real u: 1
  // The pictures the card shows: one, or several it crossfades through (a
  // theme's preview and its wallpapers).
  property var pictures: []
  property bool video: false
  // { primary, secondary, tertiary, container, surface } or null while read.
  property var roles: null
  property string title: ""
  property string meta: ""
  // 0..1, how far in front this card is.
  property real front: 0
  // Shade over a card further back.
  property real dim: 0
  property bool current: false
  property bool favourite: false
  // Crossfade through `pictures` (only while the card is in view).
  property bool cycling: false
  // A band of light across the picture, -0.35..1.35 (-1 for none).
  property real shine: -1

  readonly property alias hovered: mouse.containsMouse
  signal clicked()
  signal doubleClicked()

  readonly property real pad: 9 * u
  readonly property real radius: Tk.rounded ? Math.max(6, Tk.radius * 1.6) * u : 0
  readonly property real thumbRadius: Tk.rounded ? Math.max(4, Tk.radius) * u : 0
  readonly property real chipHeight: 22 * u
  readonly property rect pictureRect: Qt.rect(thumb.x, thumb.y, thumb.width, thumb.height)

  // The fallback dress, before a palette is read: the Omarchy theme's own.
  readonly property var dress: Palette.dress(roles) || ({
    low: Tk.bg, surface: Tk.popupBg, raised: Tk.surfaceHigh, ink: Tk.fg, muted: Tk.dim,
    line: Tk.outline, accent: Tk.accent, accentInk: Tk.onAccent
  })

  // The dress as colours.
  readonly property color cSurface: dress.surface
  readonly property color cRaised: dress.raised
  readonly property color cInk: dress.ink
  readonly property color cMuted: dress.muted
  readonly property color cLine: dress.line
  readonly property color cAccent: dress.accent
  readonly property color cAccentInk: dress.accentInk

  function inkOn(c) { return Tk.luminance(c) > 0.5 ? Qt.rgba(0, 0, 0, 0.78) : Qt.rgba(1, 1, 1, 0.9) }
  function popTag() { pop.restart() }

  implicitWidth: 212 * u
  implicitHeight: pad + thumb.height + 8 * u + chipHeight * 5 + 9 * u + titleText.height + 2 * u + metaText.height + pad + 2 * u

  RectangularShadow {
    anchors.fill: body
    offset.y: (8 + 10 * card.front) * card.u
    blur: (22 + 18 * card.front) * card.u
    radius: body.radius
    color: Qt.rgba(0, 0, 0, 0.42 + 0.18 * card.front)
  }

  Rectangle {
    id: body
    anchors.fill: parent
    radius: card.radius
    antialiasing: true
    color: card.cSurface
    border.width: Math.max(1, card.u * (1 + card.front * 0.6))
    border.color: Qt.tint(Tk.alpha(card.cLine, 0.85), Tk.alpha(card.cAccent, card.front * 0.85))
    Behavior on color { ColorAnimation { duration: Tk.normal } }

    // ── The picture ──
    Rounded {
      id: thumb
      x: card.pad; y: card.pad
      width: parent.width - card.pad * 2
      height: Math.round(width * 10 / 16)
      radius: card.thumbRadius

      Rectangle { anchors.fill: parent; color: card.cRaised }
      Icon {
        anchors.centerIn: parent
        visible: card.video || slideA.status !== Image.Ready && slideB.status !== Image.Ready
        name: card.video ? "movie" : slideA.status === Image.Error ? "broken_image" : "image"
        size: 22 * card.u
        color: Tk.alpha(card.cMuted, 0.5)
      }

      // Two images take turns, so a cycling card crossfades.
      Item {
        id: slides
        anchors.fill: parent
        readonly property var pics: card.video ? [] : (card.pictures || [])
        property int at: 0
        property bool flip: false
        onPicsChanged: reset()
        function reset() { at = 0; flip = false; slideB.source = ""; slideA.source = pics.length ? "file://" + pics[0] : "" }
        function advance() { at = (at + 1) % pics.length; (flip ? slideA : slideB).source = "file://" + pics[at] }
        Timer { interval: 2600 + Math.round(Math.random() * 1200); repeat: true; running: card.cycling && slides.pics.length > 1; onTriggered: slides.advance() }
        component Slide: Image {
          anchors.fill: parent
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          smooth: true
          sourceSize.width: Math.ceil(thumb.width * 1.3)
          sourceSize.height: Math.ceil(thumb.height * 1.3)
          Behavior on opacity { NumberAnimation { duration: Tk.ms(450); easing.type: Easing.InOutQuad } }
        }
        Slide { id: slideA; opacity: status === Image.Ready && !slides.flip ? 1 : 0; onStatusChanged: if (status === Image.Ready && slides.flip) slides.flip = false }
        Slide { id: slideB; opacity: status === Image.Ready && slides.flip ? 1 : 0; onStatusChanged: if (status === Image.Ready && !slides.flip && source != "") slides.flip = true }
        Row {
          visible: card.cycling && slides.pics.length > 1
          anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 6 * card.u
          spacing: 4 * card.u
          Repeater {
            model: slides.pics.length
            Rectangle {
              required property int index
              width: (index === slides.at ? 12 : 5) * card.u; height: 5 * card.u; radius: height / 2
              color: Qt.rgba(0.96, 0.96, 0.96, index === slides.at ? 1 : 0.5)
              Behavior on width { NumberAnimation { duration: Tk.ms(200) } }
            }
          }
        }
      }

      // A band of light across the picture as the card is set.
      Rectangle {
        visible: card.shine > -0.5
        width: parent.width * 0.45; height: parent.height * 2.2
        x: card.shine * parent.width * 1.2 - width / 2; y: -parent.height * 0.6
        rotation: 22
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0; color: "transparent" }
          GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.38) }
          GradientStop { position: 1; color: "transparent" }
        }
      }
    }

    // The wallpaper on screen now.
    Rectangle {
      id: currentTag
      visible: card.current
      x: thumb.x + 6 * card.u; y: thumb.y + 6 * card.u
      width: currentRow.implicitWidth + 14 * card.u; height: 20 * card.u
      radius: Tk.rounded ? height / 2 : 0
      color: card.cAccent
      Row {
        id: currentRow
        anchors.centerIn: parent; spacing: 3 * card.u
        Icon { name: "check"; size: 13 * card.u; color: card.cAccentInk; anchors.verticalCenter: parent.verticalCenter }
        Text { text: "current"; color: card.cAccentInk; font.family: Tk.font; font.pixelSize: 11 * card.u; font.weight: Font.DemiBold; textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter }
      }
      SequentialAnimation {
        id: pop
        NumberAnimation { target: currentTag; property: "scale"; from: 0.4; to: 1.18; duration: 220; easing.type: Easing.OutCubic }
        NumberAnimation { target: currentTag; property: "scale"; to: 1; duration: 260; easing.type: Easing.InOutQuad }
      }
    }

    // A heart for the favourites.
    Rectangle {
      visible: card.favourite
      anchors.right: thumb.right; anchors.top: thumb.top; anchors.margins: 6 * card.u
      width: 24 * card.u; height: width; radius: width / 2
      color: Qt.rgba(0, 0, 0, 0.45)
      Icon { anchors.centerIn: parent; anchors.verticalCenterOffset: 1; name: "favorite"; filled: true; size: 15 * card.u; color: "#ff5c7a" }
    }

    // ── The chips ──
    Rounded {
      id: chipBox
      x: card.pad; y: thumb.y + thumb.height + 8 * card.u
      width: thumb.width; height: card.chipHeight * 5
      radius: card.thumbRadius
      Column {
        anchors.fill: parent
        Repeater {
          model: [["primary", "primary"], ["secondary", "secondary"], ["tertiary", "tertiary"], ["container", "container"], ["surface", "surface"]]
          Rectangle {
            id: chip
            required property var modelData
            required property int index
            readonly property string fill: card.roles ? card.roles[modelData[1]] : ""
            width: chipBox.width; height: card.chipHeight
            color: fill ? fill : Qt.tint(card.cRaised, Qt.rgba(1, 1, 1, 0.02 + 0.025 * (4 - index)))
            Behavior on color { ColorAnimation { duration: Tk.normal } }
            Text {
              visible: chip.fill !== ""
              x: 8 * card.u; anchors.verticalCenter: parent.verticalCenter
              text: chip.modelData[0].toUpperCase()
              color: card.inkOn(chip.color)
              font.family: Tk.font; font.pixelSize: 9.5 * card.u; font.weight: Font.Bold; font.letterSpacing: 1.1 * card.u
              textFormat: Text.PlainText
            }
            Text {
              visible: chip.fill !== ""
              anchors.right: parent.right; anchors.rightMargin: 8 * card.u; anchors.verticalCenter: parent.verticalCenter
              text: String(chip.fill).toUpperCase()
              color: card.inkOn(chip.color)
              opacity: 0.85
              font.family: Tk.font; font.pixelSize: 9.5 * card.u
              textFormat: Text.PlainText
            }
          }
        }
      }
    }

    Text {
      id: titleText
      x: card.pad + 2 * card.u
      y: chipBox.y + chipBox.height + 9 * card.u
      width: parent.width - x * 2
      text: card.title
      elide: Text.ElideRight
      color: card.cInk
      font.family: Tk.font; font.pixelSize: 13.5 * card.u; font.weight: Font.DemiBold
      textFormat: Text.PlainText
    }
    Text {
      id: metaText
      x: titleText.x
      y: titleText.y + titleText.height + 2 * card.u
      width: titleText.width
      text: card.meta
      elide: Text.ElideRight
      color: card.cMuted
      font.family: Tk.font; font.pixelSize: 11 * card.u
      textFormat: Text.PlainText
    }

    // Further back, a little shade (lifted while hovered).
    Rectangle {
      anchors.fill: parent
      radius: body.radius
      color: "black"
      opacity: mouse.containsMouse ? 0 : card.dim
      visible: opacity > 0.005
      Behavior on opacity { NumberAnimation { duration: 170 } }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: card.clicked()
    onDoubleClicked: card.doubleClicked()
  }
}
