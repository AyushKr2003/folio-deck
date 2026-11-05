import QtQuick
import QtQuick.Effects
import ".."

// Clips what's inside it to a rounded rectangle, corners included (`clip`
// only cuts to the square bounds, so pictures poke out of rounded cards).
// Put images, previews or whole card contents inside.
Item {
  id: r
  property real radius: Tk.radius
  default property alias content: inner.data

  Item {
    id: inner
    anchors.fill: parent
    layer.enabled: r.width > 0 && r.height > 0
    layer.smooth: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: mask
      // A soft threshold keeps the curved edge antialiased.
      maskThresholdMin: 0.5
      maskSpreadAtMin: 1.0
    }
  }
  Rectangle {
    id: mask
    anchors.fill: parent
    radius: r.radius
    color: "black"
    visible: false
    layer.enabled: true
    layer.smooth: true
  }
}
