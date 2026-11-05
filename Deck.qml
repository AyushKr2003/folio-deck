pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "core/Palette.js" as Palette

// Folio Deck · entry point of the `folio.deck` overlay plugin.
//
// A wallpaper picker of paint-chip cards along the foot of the screen. Every
// wallpaper is a card: the picture, its palette as five named chips with
// their hex codes, and the file's name, format, size and weight, held on a
// wide arc. Nothing covers the desktop: as you browse, the real background
// changes to the card in front (Omarchy's `background set`), so you see each
// one where it will live. Enter keeps it (`omarchy-theme-bg-set`); Esc, or a
// click anywhere else, puts the one you had back.
//
// Open it with `omarchy-shell shell toggle folio.deck` (payload, optional:
// {"mode": "wallpaper|theme", "source": "theme|all|folder"}). It works under any bar.
//
// Keys: ←→ or the wheel browse, Home/End, PgUp/PgDn, Enter keep,
// S sort (name, colour, newest), R random, Tab source, T wallpapers/themes,
// Esc put back. In theme mode the cards are Omarchy themes (preview picture
// and colour chips); Enter applies one with `omarchy-theme-set`.
Item {
  id: root

  // Injected by the host.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  // Read by the host to know whether a toggle should close it.
  property bool opened: false

  function open(payload) {
    var args = {}
    try { args = JSON.parse(payload || "{}") || {} } catch (e) {}
    deck.sort = Store.get("sort")
    deck.mode = ["wallpaper", "theme"].indexOf(args.mode) >= 0 ? args.mode : Store.get("mode")
    deck.themeTurned = false
    deck.source = ["theme", "all", "folder"].indexOf(args.source) >= 0 ? args.source : Store.get("source")
    var m = Hyprland.focusedMonitor
    var name = m && m.name ? m.name : ""
    for (var i = 0; i < Quickshell.screens.length; i++) if (Quickshell.screens[i].name === name) deck.screen = Quickshell.screens[i]
    deck.original = ""
    deck.settled = false
    deck.kept = false
    opened = true
  }
  // For scripts and tests, through the host:
  //   omarchy-shell shell call folio.deck step 1|-1   browse
  //   omarchy-shell shell call folio.deck keep ""      keep the card in front
  //   omarchy-shell shell call folio.deck wallpapers ""   open (or switch) to wallpapers
  //   omarchy-shell shell call folio.deck themes ""       open (or switch) to themes
  function wallpapers() { return enter("wallpaper") }
  function themes() { return enter("theme") }
  function enter(m) {
    if (opened) deck.setMode(m); else open(JSON.stringify({ mode: m }))
    return "ok"
  }
  function step(n) { deck.goTo(deck.target + (Number(n) || 1)); return "ok" }
  function keep() { deck.keep(); return "ok" }

  // Closing without keeping puts the wallpaper you had back.
  function close() {
    if (!opened) return
    opened = false
    deck.restore()
  }

  PanelWindow {
    id: deck
    readonly property bool open: root.opened
    visible: open || fade > 0.001
    color: "transparent"
    WlrLayershell.namespace: "folio-deck"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { bottom: true; left: true; right: true }
    implicitHeight: hand.cardH * 1.1 + Tk.px(10) + Tk.px(40) + Tk.s4 * 3 + Tk.s4

    property real fade: open ? 1 : 0
    Behavior on fade { NumberAnimation { duration: Tk.normal; easing.type: Easing.OutCubic } }

    HyprlandFocusGrab {
      active: deck.open
      windows: [deck]
      onCleared: root.close()
    }

    // ── what's in the deck ──
    // Read from Store when the deck opens, written back as they change (a
    // binding to Store here would loop through its own writes).
    property string mode: "wallpaper"  // wallpaper | theme
    readonly property bool themes: mode === "theme"
    property bool themeTurned: false
    property string source: "theme"     // theme | all | folder
    property string sort: "name"        // name | colour | newest
    onSortChanged: if (open) Store.set("sort", sort)
    onSourceChanged: { sourceDirs(); if (open) Store.set("source", source) }

    readonly property var list: {
      Palettes.revision
      if (themes) {
        var t = Themes.names.slice()
        var td = function(n) { return Themes.get(n) || {} }
        if (sort === "name") t.sort()
        else if (sort === "newest") t.sort(function(a, b) { return (td(b).mtime || 0) - (td(a).mtime || 0) })
        else t.sort(function(a, b) { return ((td(a).roles || {}).hue || 1000) - ((td(b).roles || {}).hue || 1000) })
        return t
      }
      var f = Walls.files.slice()
      var name = function(p) { return p.substring(p.lastIndexOf("/") + 1).toLowerCase() }
      if (sort === "name") f.sort(function(a, b) { return name(a) < name(b) ? -1 : name(a) > name(b) ? 1 : 0 })
      else if (sort === "newest") f.sort(function(a, b) { return ((Walls.meta[b] || {}).mtime || 0) - ((Walls.meta[a] || {}).mtime || 0) })
      else f.sort(function(a, b) {
        var ra = Palettes.rolesOf(a), rb = Palettes.rolesOf(b)
        return (ra ? ra.hue : 1000) - (rb ? rb.hue : 1000)
      })
      return f
    }
    readonly property int count: list.length
    property real position: 0
    property int target: 0
    readonly property string front: count ? list[Math.max(0, Math.min(count - 1, target))] : ""
    readonly property int reach: 12

    // The card in use: the wallpaper (or theme) the deck would put back.
    readonly property string inUse: themes ? Themes.current : original
    function nameOf(p) { if (themes) return Themes.titleOf(p); return p.substring(p.lastIndexOf("/") + 1).replace(/\.[^.]+$/, "") }
    function sourceDirs() { Walls.source = source }

    onOpenChanged: if (open) { sourceDirs(); Walls.scan(); Themes.scan(); keys.forceActiveFocus() }

    // T flips between wallpapers and themes. Leaving the wallpapers puts the
    // original back first; coming back turns to the one in use.
    function setMode(m) {
      if (m === mode) return
      previewLater.stop()
      if (!themes && !kept && previewing && original && previewing !== original)
        Quickshell.execDetached(["omarchy-shell", "-q", "background", "set", original])
      previewing = original
      mode = m
      Store.set("mode", m)
      var at = list.indexOf(m === "theme" ? Themes.current : original)
      goTo(at >= 0 ? at : 0, true)
      askPalettes()
    }

    // ── live preview on the real background ──
    property string original: ""       // the wallpaper when the deck opened
    // False until the opening scan has said which wallpaper is in use and the
    // deck has turned to it; browsing previews only after that.
    property bool settled: false
    property bool kept: false
    property string previewing: ""
    // The wallpaper as the scan found it, before any preview moved it.
    // Reads the card from `target` itself: in onTargetChanged the `front`
    // binding may not have caught up yet.
    function preview() {
      var f = count ? list[Math.max(0, Math.min(count - 1, target))] : ""
      if (themes || !open || !settled || !f || Walls.isVideo(f) || f === previewing) return
      previewing = f
      previewLater.restart()
    }
    Timer {
      id: previewLater
      interval: 160
      onTriggered: if (deck.open && deck.previewing) Quickshell.execDetached(["omarchy-shell", "-q", "background", "set", deck.previewing])
    }
    function restore() {
      previewLater.stop()
      if (!kept && previewing && original && previewing !== original)
        Quickshell.execDetached(["omarchy-shell", "-q", "background", "set", original])
      previewing = ""
    }
    function keep() {
      if (!front) return
      kept = true
      previewLater.stop()
      previewing = ""
      if (themes) Themes.set(front); else Walls.set(front)
      root.opened = false
    }

    property string _frontBefore: ""
    // The scan that opening runs says which wallpaper is in use: turn to it
    // once (it is also the one to put back if nothing is kept).
    Connections {
      target: Walls
      function onScanned() {
        if (!deck.open || deck.settled) return
        deck.original = Walls.current
        deck.previewing = Walls.current
        if (!deck.themes) {
          var at = deck.list.indexOf(Walls.current)
          deck.goTo(at >= 0 ? at : 0, true)
        }
        deck.settled = true
        deck.askPalettes()
      }
    }
    // Likewise the theme scan turns to the theme in use, once.
    Connections {
      target: Themes
      function onScanned() {
        if (!deck.open || !deck.themes || deck.themeTurned) return
        deck.themeTurned = true
        var at = deck.list.indexOf(Themes.current)
        deck.goTo(at >= 0 ? at : 0, true)
      }
    }
    // A re-sort or a new source keeps the card in front.
    onListChanged: {
      if (settled) {
        var i = list.indexOf(_frontBefore)
        goTo(i >= 0 ? i : Math.min(target, count - 1), true)
      }
      askPalettes()
    }
    onTargetChanged: { _frontBefore = count ? list[Math.max(0, Math.min(count - 1, target))] : ""; askPalettes(); preview() }

    // Palettes: the cards in hand first, then the rest when sorting by colour.
    function askPalettes() {
      if (!open || !count || themes) return
      var order = []
      for (var d = 0; d <= Math.max(reach + 4, sort === "colour" ? count : 0); d++) {
        if (target + d < count) order.push(list[target + d])
        if (d && target - d >= 0) order.push(list[target - d])
        if (order.length >= count) break
      }
      Palettes.want(order, function(p) { return (Walls.meta[p] || {}).mtime || 0 })
    }

    function goTo(i, instant) {
      target = Math.max(0, Math.min(count - 1, i))
      if (instant) { turn.stop(); position = target } else { turn.from = position; turn.to = target; turn.restart() }
    }
    NumberAnimation { id: turn; target: deck; property: "position"; duration: Tk.ms(280); easing.type: Easing.OutCubic }

    // A soft shade under the cards so they read over any wallpaper.
    Rectangle {
      anchors.fill: parent
      opacity: deck.fade
      gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: Tk.alpha(Tk.bg, 0.75) } }
    }
    MouseArea {
      anchors.fill: parent
      onWheel: function(w) { deck.goTo(deck.target + ((w.angleDelta.y || w.angleDelta.x) > 0 ? -1 : 1)) }
    }

    // ── the hand: cards on a wide arc ──
    Item {
      id: hand
      anchors.fill: parent
      opacity: deck.fade
      readonly property real cardW: Tk.px(212)
      readonly property real cardH: Tk.px(352)
      readonly property real pad: Tk.s3
      readonly property real arcR: Math.max(1300, (deck.screen ? deck.screen.width : 1920) * 0.85)
      readonly property real step: 6.6
      readonly property real cx: width / 2
      // The front card's foot sits just above the bottom edge.
      readonly property real cy: height - Tk.s4 + arcR - cardH + (1 - deck.fade) * cardH * 0.4

      Repeater {
        model: deck.count
        Item {
          id: card
          required property int index
          readonly property string file: deck.list[index]
          readonly property real d: index - deck.position
          readonly property bool inHand: Math.abs(d) <= deck.reach + 1
          readonly property bool isFront: index === deck.target
          readonly property real ang: d * hand.step
          readonly property var roles: inHand ? (deck.themes ? Themes.rolesOf(file) : Palettes.rolesOf(file)) : null
          readonly property var info: inHand && !deck.themes ? Palettes.info(file) : null
          readonly property var theme: inHand && deck.themes ? Themes.get(file) : null
          readonly property real lift: isFront ? Tk.px(10) : Math.max(0, 1 - Math.abs(d)) * Tk.px(10)
          visible: inHand
          z: 100 - Math.abs(d)
          width: hand.cardW; height: hand.cardH
          x: hand.cx + Math.sin(ang * Math.PI / 180) * hand.arcR - width / 2
          y: hand.cy - Math.cos(ang * Math.PI / 180) * hand.arcR - lift
          rotation: ang
          transformOrigin: Item.Bottom
          scale: isFront ? 1.1 : 1
          opacity: Math.abs(d) > deck.reach ? 0 : 1

          // Picture, chips, caption.
          Rounded {
            anchors.fill: parent
            radius: Tk.radius
            Rectangle { anchors.fill: parent; color: Tk.popupBg }
            Rounded {
              id: pic
              x: hand.pad; y: hand.pad
              width: parent.width - hand.pad * 2; height: Tk.px(140)
              radius: Math.max(0, Tk.radius - Tk.px(4))
              Image {
                anchors.fill: parent
                source: !card.inHand ? "" : deck.themes ? (Themes.previewOf(card.file) ? "file://" + Themes.previewOf(card.file) : "") : !Walls.isVideo(card.file) ? "file://" + card.file : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 424; sourceSize.height: 300
              }
              Icon { anchors.centerIn: parent; visible: !deck.themes && Walls.isVideo(card.file); name: "movie"; size: Tk.px(40); color: Tk.dim }
            }
            Rounded {
              x: hand.pad; y: pic.y + pic.height + Tk.s2
              width: parent.width - hand.pad * 2; height: Tk.px(23) * 5
              radius: Math.max(0, Tk.radius - Tk.px(4))
            Column {
              anchors.fill: parent
              Repeater {
                model: [["Primary", "primary"], ["Secondary", "secondary"], ["Tertiary", "tertiary"], ["Container", "container"], ["Surface", "surface"]]
                Rectangle {
                  required property var modelData
                  readonly property color chip: card.roles ? card.roles[modelData[1]] : Tk.alpha(Tk.fg, 0.07)
                  readonly property color ink: Tk.luminance(chip) > 0.55 ? "#141414" : "#f4f4f4"
                  width: parent.width; height: Tk.px(23)
                  color: chip
                  Text {
                    x: Tk.s3; anchors.verticalCenter: parent.verticalCenter
                    text: parent.modelData[0].toUpperCase()
                    color: card.roles ? parent.ink : Tk.faint
                    font.family: Tk.font; font.pixelSize: Tk.fsCaption - 1; font.weight: Font.Bold; font.letterSpacing: 1.2
                    textFormat: Text.PlainText
                  }
                  Text {
                    anchors.right: parent.right; anchors.rightMargin: Tk.s3; anchors.verticalCenter: parent.verticalCenter
                    text: card.roles ? card.roles[parent.modelData[1]] : "······"
                    color: card.roles ? Tk.alpha(parent.ink, 0.85) : Tk.faint
                    font.family: Tk.font; font.pixelSize: Tk.fsCaption - 1
                    textFormat: Text.PlainText
                  }
                }
              }
            }
            }
            Column {
              anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
              anchors.margins: hand.pad
              spacing: Tk.px(2)
              Label { width: parent.width; text: deck.nameOf(card.file); font.weight: Font.Bold; font.pixelSize: Tk.fsLarge }
              Label {
                width: parent.width
                text: deck.themes ? (card.theme ? card.theme.mode + "  ·  " + card.theme.origin : "reading…") : card.info ? (card.info.fmt + "  ·  " + card.info.w + " × " + card.info.h + "  ·  " + Palette.humanSize(card.info.size)) : "reading…"
                color: Tk.dim; font.pixelSize: Tk.fsCaption
              }
            }
            // A name tag on the front card's top edge, like a chip's code.
            Rectangle {
              visible: card.isFront
              anchors.right: parent.right; anchors.top: parent.top
              width: tag.implicitWidth + Tk.s3; height: Tk.px(20)
              color: card.roles ? card.roles.primary : Tk.accent
              Text { id: tag; anchors.centerIn: parent; text: "// " + deck.nameOf(card.file).slice(0, 12); color: Tk.luminance(parent.color) > 0.55 ? "#141414" : "#f4f4f4"; font.family: Tk.font; font.pixelSize: Tk.fsCaption - 1; textFormat: Text.PlainText }
            }
          }
          Rectangle {
            anchors.fill: parent
            radius: Tk.radius
            color: "transparent"
            border.width: card.isFront ? 2 : 1
            border.color: card.isFront ? (card.roles ? card.roles.primary : Tk.accent) : Tk.alpha(Tk.fg, 0.18)
          }
          Rectangle {
            visible: card.file === deck.inUse
            x: Tk.s2; y: Tk.s2
            width: cur.implicitWidth + Tk.s3; height: Tk.px(20); radius: Tk.pill(height)
            color: Tk.alpha(Tk.bg, 0.85)
            Row { id: cur; anchors.centerIn: parent; spacing: Tk.px(3)
              Icon { name: "check"; size: Tk.px(13); color: Tk.accent; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "current"; color: Tk.fg; font.family: Tk.font; font.pixelSize: Tk.fsCaption; textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter } }
          }
          MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: card.isFront ? deck.keep() : deck.goTo(card.index)
            onDoubleClicked: { deck.goTo(card.index); deck.keep() }
          }
        }
      }
    }

    Label {
      anchors.centerIn: parent
      visible: deck.count === 0 && deck.open
      text: deck.themes ? "No themes found. Press T for wallpapers." : deck.source === "folder" ? "No pictures in " + Walls.folder + ". Press Tab for another source." : "No wallpapers here. Press Tab for another source."
      color: Tk.fg
    }

    Item {
      id: keys
      focus: true
      Keys.onPressed: function(e) {
        var k = e.key
        if (k === Qt.Key_Escape) root.close()
        else if (k === Qt.Key_Left || k === Qt.Key_H) deck.goTo(deck.target - 1)
        else if (k === Qt.Key_Right || k === Qt.Key_L) deck.goTo(deck.target + 1)
        else if (k === Qt.Key_PageUp) deck.goTo(deck.target - 8)
        else if (k === Qt.Key_PageDown) deck.goTo(deck.target + 8)
        else if (k === Qt.Key_Home) deck.goTo(0)
        else if (k === Qt.Key_End) deck.goTo(deck.count - 1)
        else if (k === Qt.Key_R) deck.goTo(Math.floor(Math.random() * deck.count))
        else if (k === Qt.Key_Return || k === Qt.Key_Enter) deck.keep()
        else if (k === Qt.Key_S) { var s = ["name", "colour", "newest"]; deck.sort = s[(s.indexOf(deck.sort) + 1) % 3] }
        else if (k === Qt.Key_T) deck.setMode(deck.themes ? "wallpaper" : "theme")
        else if (k === Qt.Key_Tab) { if (!deck.themes) { var o = ["theme", "all", "folder"]; deck.source = o[(o.indexOf(deck.source) + 1) % 3] } }
        else return
        e.accepted = true
      }
    }
  }
}
