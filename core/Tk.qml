pragma Singleton
import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons

// Folio Deck's tokens, all from the running Omarchy theme: colours from
// Commons.Color, sizes from Omarchy's spacing scale, corners from Hyprland's
// rounding (Style.cornerRadius), motion through Style.duration.
Singleton {
  readonly property color fg: Commons.Color.foreground
  readonly property color bg: Commons.Color.background
  readonly property color accent: Commons.Color.accent
  readonly property color urgent: Commons.Color.urgent
  readonly property color popupBg: Commons.Color.popups ? Commons.Color.popups.background : bg
  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
  function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1) }
  function luminance(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }
  readonly property color surfaceHigh: mix(bg, fg, 0.08)
  readonly property color surfaceHigher: mix(bg, fg, 0.13)
  readonly property color outline: alpha(fg, 0.14)
  readonly property color dim: alpha(fg, 0.62)
  readonly property color faint: alpha(fg, 0.38)
  readonly property color hover: alpha(fg, 0.07)
  readonly property color onAccent: luminance(accent) > 0.55 ? "#111111" : "#f5f5f5"

  readonly property string font: Style.fontFamily
  readonly property string icons: "Material Symbols Rounded"
  function px(n) { return Math.round(n * Style.effectiveSpacingScale) }
  function fs(n) { return Math.max(1, Math.round(n * Style.fontScale)) }
  readonly property int fsCaption: fs(10)
  readonly property int fsSmall: fs(11)
  readonly property int fsBody: fs(12)
  readonly property int fsLarge: fs(13)
  readonly property int fsHeading: fs(18)
  readonly property int s1: px(4)
  readonly property int s2: px(8)
  readonly property int s3: px(12)
  readonly property int s4: px(16)
  readonly property int iconSmall: px(16)
  readonly property int icon: px(20)
  readonly property int iconLarge: px(24)
  readonly property int hChip: px(28)
  readonly property int hControl: px(32)

  readonly property int radius: Math.max(0, Style.cornerRadius)
  readonly property bool rounded: radius > 0
  function pill(size) { return rounded ? size / 2 : 0 }
  function corner(w, h) { return Math.min(radius, Math.min(w, h) / 2) }

  function ms(n) { return Style.duration(n) }
  readonly property int fast: ms(140)
  readonly property int normal: ms(220)
}
