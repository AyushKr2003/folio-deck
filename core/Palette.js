.pragma library

// Turns a wallpaper's most common colours (scripts/palette) into the five
// chips a deck card shows: primary, secondary, tertiary, container, surface.
// Primary is the most vivid colour with real presence; secondary the next
// one with a different hue; tertiary the one furthest round the wheel from
// primary; container a deep shade of primary; surface the darkest calm one.

function hexToRgb(h) { var n = parseInt(String(h).slice(1), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255] }
function rgbToHex(c) { return "#" + c.map(function(v) { var s = Math.max(0, Math.min(255, Math.round(v))).toString(16); return s.length < 2 ? "0" + s : s }).join("").toUpperCase() }

function hsl(hex) {
  var c = hexToRgb(hex).map(function(v) { return v / 255 })
  var max = Math.max(c[0], c[1], c[2]), min = Math.min(c[0], c[1], c[2]), l = (max + min) / 2, h = 0, s = 0
  if (max !== min) {
    var d = max - min
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
    if (max === c[0]) h = (c[1] - c[2]) / d + (c[1] < c[2] ? 6 : 0)
    else if (max === c[1]) h = (c[2] - c[0]) / d + 2
    else h = (c[0] - c[1]) / d + 4
    h *= 60
  }
  return { h: h, s: s, l: l }
}
function hueGap(a, b) { var d = Math.abs(a - b) % 360; return d > 180 ? 360 - d : d }
function shade(hex, f) { return rgbToHex(hexToRgb(hex).map(function(v) { return v * f })) }

function roles(colors) {
  if (!colors || !colors.length) return null
  var total = colors.reduce(function(a, c) { return a + c[1] }, 0) || 1
  var list = colors.map(function(c) { var x = hsl(c[0]); return { hex: c[0], share: c[1] / total, h: x.h, s: x.s, l: x.l } })
  function vivid(c) { return c.s * (1 - Math.abs(c.l - 0.55) * 1.2) + Math.sqrt(c.share) * 0.35 }
  var byVivid = list.slice().sort(function(a, b) { return vivid(b) - vivid(a) })
  var primary = byVivid[0]
  var secondary = byVivid.find(function(c) { return c !== primary && hueGap(c.h, primary.h) > 18 }) || byVivid[1] || primary
  var tertiary = list.filter(function(c) { return c !== primary && c !== secondary })
    .sort(function(a, b) { return hueGap(b.h, primary.h) * (0.3 + b.s) - hueGap(a.h, primary.h) * (0.3 + a.s) })[0] || secondary
  var surface = list.slice().sort(function(a, b) { return (a.l + a.s * 0.3) - (b.l + b.s * 0.3) })[0]
  return {
    primary: primary.hex, secondary: secondary.hex, tertiary: tertiary.hex,
    container: shade(primary.hex, primary.l > 0.5 ? 0.45 : 0.7),
    surface: surface.hex,
    hue: primary.s < 0.12 ? 999 : primary.h       // greys sort last
  }
}

function hslHex(h, s, l) {
  h = ((h % 360) + 360) % 360; s = Math.max(0, Math.min(1, s)); l = Math.max(0, Math.min(1, l))
  var c = (1 - Math.abs(2 * l - 1)) * s, x = c * (1 - Math.abs((h / 60) % 2 - 1)), m = l - c / 2
  var r = h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x] : h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x]
  return rgbToHex(r.map(function(v) { return (v + m) * 255 }))
}

// What a card (and the picker round it) wears for a palette: a dark scheme
// tinted with the wallpaper's own colours, like a Material You dark theme.
// surface/low/raised are the card and glass, ink/muted the text, line the
// edges, accent the primary lifted to read on them, accentInk text on it.
function dress(r) {
  if (!r) return null
  var p = hsl(r.primary), base = hsl(r.surface)
  var h = p.s < 0.12 ? base.h : p.h
  var s = Math.min(0.32, (p.s < 0.12 ? base.s : p.s) * 0.45)
  var al = Math.max(0.64, Math.min(0.80, p.l)), as = p.s < 0.12 ? 0.18 : Math.max(0.45, Math.min(0.85, p.s))
  return {
    low: hslHex(h, s, 0.085),
    surface: hslHex(h, s, 0.115),
    raised: hslHex(h, s, 0.17),
    ink: hslHex(h, s * 0.6, 0.91),
    muted: hslHex(h, s * 0.5, 0.72),
    line: hslHex(h, s * 0.6, 0.33),
    accent: hslHex(p.h, as, al),
    accentInk: hslHex(p.h, Math.min(0.6, as), 0.13)
  }
}

function humanSize(b) {
  if (b > 1048576) return (b / 1048576).toFixed(1) + " MB"
  if (b > 1024) return Math.round(b / 1024) + " KB"
  return b + " B"
}
