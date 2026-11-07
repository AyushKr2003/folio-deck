pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "core/Palette.js" as Palette

// Folio Deck · entry point of the `folio.deck` overlay plugin.
//
// A wallpaper picker: a deck of paint-chip cards. Every wallpaper is a card
// dressed in the colours it would bring (its palette's surface, ink and
// accent), with its five chips and their hex codes, its name, format, size
// and weight. The cards are held fanned like a hand along the foot of the
// screen; behind them the whole screen previews the card in front at full
// size, and the picker's own glass and accents take on its colours, so
// browsing is trying each wallpaper on. The ribbon under the header is the
// whole deck in colour: hover for a glimpse, click or drag to go there.
//
// Choosing a card: it leaves the hand for the middle of the screen while the
// rest of the hand is put away, lights up as it's set, then its picture
// grows into the wallpaper and the picker goes. With that turned off in the
// settings (the gear), a card is set at once and the deck stays open.
//
// In theme mode (T) the cards are Omarchy themes: each crossfades through
// its preview and wallpapers, wears the theme's own colours, and Enter
// applies it with `omarchy-theme-set`.
//
// Keys: ←→ browse, Home/End, PgUp/PgDn, R random, Enter set, F favourite,
// S sort, Space peek (hold, or tap to keep), Tab source, T wallpapers or
// themes, Esc close. Mouse: wheel or drag anywhere to browse, click a card to
// bring it to the front, click the front card (or double-click any) to set
// it, click the picture itself to peek.
//
// Open it with `omarchy-shell folio-deck wallpapers|themes|toggle`, or the
// host's `omarchy-shell shell toggle folio.deck` (payload, optional:
// {"mode": "wallpaper|theme", "source": "theme|all|folder|favourites"}).
Item {
  id: root

  // Injected by the host.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  // Read by the host to know whether a toggle should close it.
  property bool opened: false

  readonly property var sources: ["theme", "all", "folder", "favourites"]

  function open(payload) {
    // JSON ({"mode": "theme", "source": "all"}) or one bare word: a mode
    // (theme(s), wallpaper(s)) or a source (all, folder, favourites).
    var args = {}
    var word = String(payload || "").trim().toLowerCase().replace(/^"|"$/g, "")
    if (/^themes?$/.test(word)) args = { mode: "theme" }
    else if (/^wallpapers?$|^walls?$/.test(word)) args = { mode: "wallpaper" }
    else if (word === "all" || word === "folder" || word === "favourites") args = { mode: "wallpaper", source: word }
    else try { args = JSON.parse(payload || "{}") || {} } catch (e) {}
    if (typeof args !== "object" || args === null) args = {}
    deck.begin(["wallpaper", "theme"].indexOf(args.mode) >= 0 ? args.mode : Store.get("mode"),
               sources.indexOf(args.source) >= 0 ? args.source : Store.get("source"))
    var m = Hyprland.focusedMonitor
    var name = m && m.name ? m.name : ""
    for (var i = 0; i < Quickshell.screens.length; i++) if (Quickshell.screens[i].name === name) deck.screen = Quickshell.screens[i]
    opened = true
  }
  function close() {
    if (!opened) return
    opened = false
  }
  // For scripts and tests, through the host:
  //   omarchy-shell shell call folio.deck step 1|-1      browse
  //   omarchy-shell shell call folio.deck keep ""         set the card in front
  //   omarchy-shell shell call folio.deck wallpapers ""   open (or switch) to wallpapers
  //   omarchy-shell shell call folio.deck themes ""       open (or switch) to themes
  function wallpapers() { return enter("wallpaper") }
  function themes() { return enter("theme") }
  function enter(m) {
    if (opened) deck.setMode(m); else open(JSON.stringify({ mode: m }))
    return "ok"
  }
  function step(n) { deck.go(deck.target + (Number(n) || 1)); return "ok" }
  function keep() { deck.pickCurrent(); return "ok" }

  // Its own IPC target, so no host `call` (which wants a third argument):
  //   omarchy-shell folio-deck wallpapers   open on wallpapers (again: close)
  //   omarchy-shell folio-deck themes       open on themes (again: close)
  //   omarchy-shell folio-deck toggle | close | keep | step <n> | peek | mode | front
  //   omarchy-shell folio-deck source theme|all|folder|favourites | count
  IpcHandler {
    target: "folio-deck"
    function wallpapers(): string { return root.flip("wallpaper") }
    function themes(): string { return root.flip("theme") }
    function toggle(): string { if (root.opened) root.close(); else root.open(""); return root.opened ? "open" : "closed" }
    function close(): string { root.close(); return "closed" }
    function keep(): string { return root.keep() }
    function step(n: int): string { return root.step(n) }
    function peek(): string { deck.peekKept = !deck.peekKept; return deck.peekKept ? "peeking" : "deck" }
    function source(s: string): string { if (root.sources.indexOf(s) < 0) return "unknown source"; deck.setSource(s); return s }
    function count(): string { return root.opened ? deck.source + " " + deck.count : "closed" }
    function mode(): string { return root.opened ? deck.mode : "closed" }
    function front(): string { return root.opened ? deck.front : "" }
  }
  function flip(m) {
    if (opened && deck.mode === m) { close(); return "closed" }
    enter(m)
    return m
  }

  onOpenedChanged: if (opened) deck.showUp(); else deck.putAway()

  PanelWindow {
    id: deck
    visible: false
    color: "transparent"
    WlrLayershell.namespace: "folio-deck"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened && !dry ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    // ── What's in the deck ──
    // Read from Store as the deck opens, written back as they change (a
    // binding to Store here would loop through its own writes).
    property string mode: "wallpaper"   // wallpaper | theme
    readonly property bool themes: mode === "theme"
    property string source: "theme"     // theme | all | folder | favourites
    property string sort: "name"        // name | colour | newest
    readonly property var sorts: ["name", "colour", "newest"]

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
      if (source === "favourites") f = f.filter(function(p) { return Walls.isFav(p) })
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
    // The index in front, and the deck's position (fractional while it moves).
    property int target: 0
    property real pos: 0
    readonly property string front: count ? list[Math.max(0, Math.min(count - 1, target))] : ""
    // The card in use: the wallpaper (or theme) on the desktop now.
    readonly property string inUse: themes ? Themes.current : Walls.current
    property string _frontBefore: ""
    // False until the opening scan has said which card is in use and the
    // deck has turned to it.
    property bool settled: false

    function nameOf(p) { if (themes) return Themes.titleOf(p); return p.substring(p.lastIndexOf("/") + 1).replace(/\.[^.]+$/, "") }
    function rolesOf(p) { return themes ? Themes.rolesOf(p) : Palettes.rolesOf(p) }
    function picturesOf(p) {
      if (!p) return []
      if (themes) return Themes.picturesOf(p)
      if (Walls.isVideo(p)) return []
      var t = Palettes.thumbOf(p)
      return [t || p]
    }
    // The full-screen preview of a card: a theme's preview, a wallpaper itself.
    function previewOf(p) {
      if (!p) return ""
      if (themes) { var t = Themes.previewOf(p) || (Themes.picturesOf(p)[0] || ""); return t ? "file://" + t : "" }
      return Walls.isVideo(p) ? "" : "file://" + p
    }
    // What a chosen card grows into: the wallpaper it sets.
    function bloomOf(p) {
      if (!p) return ""
      if (themes) { var t = Themes.get(p); var b = t && t.backgrounds && t.backgrounds.length ? t.backgrounds[0] : Themes.previewOf(p); return b ? "file://" + b : "" }
      return previewOf(p)
    }
    function metaOf(p) {
      if (!p) return ""
      if (themes) { var t = Themes.get(p); return t ? (t.mode === "light" ? "Light" : "Dark") + "  ·  " + (t.origin === "user" ? "yours" : "built-in") + "  ·  " + Themes.picturesOf(p).length + " pictures" : "reading…" }
      var i = Palettes.info(p)
      return i ? i.fmt + "  ·  " + i.w + " × " + i.h + "  ·  " + Palette.humanSize(i.size) : "reading…"
    }
    function sourceDirs() { Walls.source = source }

    // ── The hand ──
    // Design pixels scale with the screen (1920×1200 is 1).
    readonly property real u: Math.max(0.6, Math.min(width / 1920, height / 1200))
    // Cards shown on each side of the one in front, and the slots that show
    // them (two spare: a slot changes card only out of sight).
    readonly property int side: 7
    readonly property int slots: 2 * side + 3
    readonly property real cardW: 212 * u
    readonly property real cardH: gauge.implicitHeight
    // The cards turn round a pivot far below the screen, like a hand.
    readonly property real pivotX: width / 2
    readonly property real pivotY: height + 1650 * u
    readonly property real handR: pivotY - (height - 196 * u)
    readonly property real lift: 66 * u
    readonly property real frontScale: 1.22
    // Angles between the front card and its neighbours, and the rest.
    readonly property real step1: 204 * u / handR
    readonly property real stepN: 132 * u / handR
    // Top of the card in front, at rest.
    readonly property real frontTop: pivotY - handR - lift - cardH * frontScale / 2

    // ── Choreography, 0..1 ──
    property real shown: 0
    // The cards being dealt (they rise from below, the middle first).
    property real deal: 0
    readonly property bool closing: closeAnim.running
    // Peeking: the deck steps aside for a clear view of the picture.
    property bool peekHeld: false
    property bool peekKept: false
    property real peekPressedAt: 0
    property real peek: (peekHeld || peekKept) && !choosing ? 1 : 0
    Behavior on peek { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    property bool settingsOpen: false

    // ── Choosing ──
    property string chosen: ""
    readonly property bool choosing: chosen !== ""
    property bool chosenSet: false
    // The picker steps back, and the screen dims behind the chosen card.
    property real hush: 0
    property real spot: 0
    readonly property real midScale: Math.max(1.4, Math.min(2.4, 0.5 * height / Math.max(1, cardH)))

    // ── Opening and closing ──
    function begin(m, s) {
      resetChoice()
      settled = false
      peekKept = false; peekHeld = false
      settingsOpen = false
      sort = Store.get("sort")
      mode = m
      source = s
      sourceDirs()
      Walls.scan()
      Themes.scan()
      if (themes) { var at = list.indexOf(Themes.current); place(at >= 0 ? at : 0) }
    }
    function showUp() {
      closeAnim.stop()
      visible = true
      keys.forceActiveFocus()
      askPalettes()
      updateBackdrop()
      openAnim.restart()
    }
    function putAway() {
      openAnim.stop()
      if (visible) closeAnim.restart()
    }

    HyprlandFocusGrab {
      active: root.opened && !deck.dry
      windows: [deck]
      onCleared: root.close()
    }

    // The opening scan says which wallpaper is in use: turn to it, once.
    Connections {
      target: Walls
      function onScanned() {
        if (!root.opened || deck.settled || deck.themes) return
        var at = deck.list.indexOf(Walls.current)
        deck.place(at >= 0 ? at : 0)
        deck.settled = true
        deck.askPalettes()
      }
    }
    Connections {
      target: Themes
      function onScanned() {
        if (!root.opened || deck.settled || !deck.themes) return
        var at = deck.list.indexOf(Themes.current)
        deck.place(at >= 0 ? at : 0)
        deck.settled = true
      }
    }
    // A re-sort or a new source keeps the card in front.
    onListChanged: {
      var i = list.indexOf(_frontBefore)
      if (i >= 0) place(i)
      else if (target > count - 1) place(Math.max(0, count - 1))
      askPalettes()
    }
    onTargetChanged: { askPalettes(); backdropLater.restart() }
    onModeChanged: backdropLater.restart()

    // Palettes: the cards in hand first, then the rest when sorting by colour.
    function askPalettes() {
      if (!root.opened || !count || themes) return
      var order = []
      var at = Math.max(0, Math.min(count - 1, target))
      for (var d = 0; d <= Math.max(side + 4, sort === "colour" ? count : 0); d++) {
        if (at + d < count) order.push(list[at + d])
        if (d && at - d >= 0) order.push(list[at - d])
        if (order.length >= count) break
      }
      Palettes.want(order, function(p) { return (Walls.meta[p] || {}).mtime || 0 })
    }

    // ── Moving through the deck ──
    // Straight to a card, no travel.
    function place(i) {
      posAnim.stop()
      target = Math.max(0, Math.min(count - 1, i))
      _frontBefore = count ? list[target] : ""
      pos = target
    }
    // To a card, the deck turning; a long way is cut short.
    function go(i) {
      if (!count || choosing) return
      i = Math.max(0, Math.min(count - 1, i))
      target = i
      _frontBefore = list[i]
      var far = Math.abs(i - pos)
      if (far > side * 2) pos = i - (i > pos ? side : -side)
      posAnim.to = i
      posAnim.duration = far > 1.5 ? 460 : 380
      posAnim.restart()
    }
    NumberAnimation { id: posAnim; target: deck; property: "pos"; duration: 380; easing.type: Easing.OutCubic }

    // A new source, order or mode: the hand is put away, the change made out
    // of sight, and the hand dealt again.
    function shuffle(change) {
      if (choosing) return
      if (!root.opened || shown < 0.5) { change(); return }
      if (shuffleAnim.running && shuffleAnim.change) shuffleAnim.change()
      shuffleAnim.change = change
      shuffleAnim.restart()
    }
    function setSort(s) { if (s !== sort) shuffle(function() { deck.sort = s; Store.set("sort", s) }) }
    function setSource(s) {
      if (themes) { setMode("wallpaper"); if (s === source) return }
      if (s !== source) shuffle(function() { deck.source = s; deck.sourceDirs(); Store.set("source", s) })
    }
    function setMode(m) {
      if (m === mode) return
      shuffle(function() {
        deck.mode = m
        Store.set("mode", m)
        var at = deck.list.indexOf(deck.inUse)
        deck.place(at >= 0 ? at : 0)
        deck.askPalettes()
      })
    }

    // ── The preview ──
    Timer { id: backdropLater; interval: 110; onTriggered: deck.updateBackdrop() }
    function updateBackdrop() { if (!choosing) backdrop.show(previewOf(front), quickOf(front)) }
    // A small copy to show at once while the full picture decodes.
    function quickOf(p) { if (!p || themes) return ""; var t = Palettes.thumbOf(p); return t ? "file://" + t : "" }

    // ── Acting on the card in front ──
    function isInUse(p) { return !!p && p === inUse }
    // FOLIO_DECK_DRY=1 (for tests) plays everything but sets nothing, and
    // leaves the keyboard alone (drive it over IPC).
    readonly property bool dry: Quickshell.env("FOLIO_DECK_DRY") === "1"
    function apply(p) { if (dry) return; if (themes) Themes.set(p); else Walls.set(p) }
    function toggleFavourite() { if (!themes && front) Walls.toggleFav(front) }
    function pickCurrent() {
      var p = front
      if (!p || choosing || closing || !root.opened) return
      if (isInUse(p)) return
      if (!Store.get("animateChoice")) { apply(p); return }
      choose(p)
    }
    // The card goes from the hand to the middle of the screen; its
    // wallpaper is set as it leaves, so it's drawn by the time it blooms.
    function choose(p) {
      posAnim.stop()
      if (shuffleAnim.running) { var c = shuffleAnim.change; shuffleAnim.change = null; shuffleAnim.stop(); if (c) c() }
      openAnim.stop()
      settingsOpen = false
      keys.forceActiveFocus()
      var from = slotOf(p)
      flight.x = from ? from.x : pivotX - cardW / 2
      flight.y = from ? from.y : frontTop + cardH * (frontScale - 1) / 2
      flight.rotation = from ? from.rotation : 0
      flight.scale = from ? from.scale : frontScale
      flight.glow = 0; flight.ring = 0; flight.pulse = 0; flight.shine = -1; flight.fade = 0; flight.bloom = 0
      chosenSet = false
      chosen = p
      backdrop.show(previewOf(p), quickOf(p))
      apply(p)
      riseAnim.restart()
    }
    function slotOf(p) {
      for (var i = 0; i < hand.count; i++) {
        var s = hand.itemAt(i)
        if (s && s.live && s.file === p) return s
      }
      return null
    }
    function resetChoice() {
      riseAnim.stop(); bloomAnim.stop(); leaveLater.stop()
      chosen = ""
      chosenSet = false
      hush = 0; spot = 0
      flight.bloom = 0
    }

    ParallelAnimation {
      id: openAnim
      NumberAnimation { target: deck; property: "shown"; to: 1; duration: 380; easing.type: Easing.OutCubic }
      NumberAnimation { target: deck; property: "deal"; to: 1; duration: 760; easing.type: Easing.OutCubic }
    }
    ParallelAnimation {
      id: closeAnim
      NumberAnimation { target: deck; property: "shown"; to: 0; duration: deck.choosing ? 340 : 240; easing.type: Easing.InCubic }
      NumberAnimation { target: deck; property: "deal"; to: 0; duration: 220; easing.type: Easing.InCubic }
      onFinished: { deck.visible = false; deck.resetChoice(); backdrop.show("") }
    }
    SequentialAnimation {
      id: shuffleAnim
      property var change: null
      NumberAnimation { target: deck; property: "deal"; to: 0.1; duration: 170; easing.type: Easing.InQuad }
      ScriptAction { script: { var c = shuffleAnim.change; shuffleAnim.change = null; if (c) c() } }
      NumberAnimation { target: deck; property: "deal"; to: 1; duration: 560; easing.type: Easing.OutCubic }
    }

    // Choosing, in three moves. 1. Slowly out of the hand to the middle of
    // the screen, upright and larger, while the rest of the hand is put away
    // and the picker steps back.
    ParallelAnimation {
      id: riseAnim
      NumberAnimation { target: deck; property: "shown"; to: 1; duration: 300; easing.type: Easing.OutCubic }
      NumberAnimation { target: deck; property: "deal"; to: 0; duration: 560; easing.type: Easing.InCubic }
      NumberAnimation { target: deck; property: "hush"; to: 1; duration: 420; easing.type: Easing.OutCubic }
      NumberAnimation { target: deck; property: "spot"; to: 1; duration: 1000; easing.type: Easing.InOutQuad }
      NumberAnimation { target: flight; property: "x"; to: deck.width / 2 - deck.cardW / 2; duration: 1250; easing.type: Easing.InOutCubic }
      NumberAnimation { target: flight; property: "y"; to: deck.height / 2 - deck.cardH / 2; duration: 1250; easing.type: Easing.InOutCubic }
      NumberAnimation { target: flight; property: "rotation"; to: 0; duration: 900; easing.type: Easing.OutCubic }
      NumberAnimation { target: flight; property: "scale"; to: deck.midScale; duration: 1250; easing.type: Easing.InOutCubic }
      NumberAnimation { target: flight; property: "glow"; to: 1; duration: 1250; easing.type: Easing.InQuad }
      onFinished: bloomAnim.restart()
    }
    // 2. Set: the tag pops, a ring goes out and light crosses the picture;
    // 3. the card falls away from round its picture, which grows into the
    // wallpaper, and the picker goes.
    SequentialAnimation {
      id: bloomAnim
      ScriptAction { script: { deck.chosenSet = true; chosenCard.popTag() } }
      ParallelAnimation {
        NumberAnimation { target: flight; property: "ring"; from: 0; to: 1; duration: 800; easing.type: Easing.OutCubic }
        NumberAnimation { target: flight; property: "shine"; from: -0.35; to: 1.35; duration: 820; easing.type: Easing.InOutSine }
        SequentialAnimation {
          NumberAnimation { target: flight; property: "pulse"; to: 1; duration: 170; easing.type: Easing.OutCubic }
          NumberAnimation { target: flight; property: "pulse"; to: 0; duration: 480; easing.type: Easing.InOutQuad }
        }
      }
      PauseAnimation { duration: 100 }
      ParallelAnimation {
        NumberAnimation { target: flight; property: "fade"; to: 1; duration: 320; easing.type: Easing.OutQuad }
        NumberAnimation { target: flight; property: "glow"; to: 0; duration: 380; easing.type: Easing.OutQuad }
        NumberAnimation { target: deck; property: "spot"; to: 0; duration: 600; easing.type: Easing.OutQuad }
        NumberAnimation { target: flight; property: "bloom"; to: 1; duration: 1000; easing.type: Easing.InOutCubic }
      }
      ScriptAction { script: leaveLater.restart() }
    }
    // The wallpaper itself is under the grown picture by now (a theme takes
    // longer to apply): then the picker goes.
    Timer { id: leaveLater; interval: deck.themes ? 900 : 250; onTriggered: root.close() }

    // ── The try-on: the picker wears the front card's colours ──
    Item {
      id: tint
      visible: false
      readonly property var dress: Palette.dress(deck.rolesOf(deck.choosing ? deck.chosen : deck.front))
      property color accent: dress ? dress.accent : Tk.accent
      property color accentInk: dress ? dress.accentInk : Tk.onAccent
      property color surface: dress ? dress.low : Tk.popupBg
      property color raised: dress ? dress.raised : Tk.surfaceHigh
      property color ink: dress ? dress.ink : Tk.fg
      property color muted: dress ? dress.muted : Tk.dim
      property color line: dress ? dress.line : Tk.outline
      Behavior on accent { ColorAnimation { duration: 420; easing.type: Easing.OutCubic } }
      Behavior on accentInk { ColorAnimation { duration: 420; easing.type: Easing.OutCubic } }
      Behavior on surface { ColorAnimation { duration: 420; easing.type: Easing.OutCubic } }
      Behavior on raised { ColorAnimation { duration: 420; easing.type: Easing.OutCubic } }
      Behavior on ink { ColorAnimation { duration: 420; easing.type: Easing.OutCubic } }
      Behavior on muted { ColorAnimation { duration: 420; easing.type: Easing.OutCubic } }
      Behavior on line { ColorAnimation { duration: 420; easing.type: Easing.OutCubic } }
    }

    // Measures a card (the deck's geometry needs its height).
    SwatchCard { id: gauge; visible: false; u: deck.u; title: "Ag"; meta: "Ag" }

    // ── The picture ──
    // The desktop dimmed, until the picture is in.
    Rectangle { anchors.fill: parent; color: "black"; opacity: 0.55 * deck.shown * (1 - deck.hush) }
    Backdrop { id: backdrop; anchors.fill: parent; opacity: deck.shown }
    // Shade at the head and the foot, so the header and the deck read on
    // any picture; it lifts while peeking.
    Rectangle {
      anchors.fill: parent
      opacity: deck.shown * (1 - 0.85 * deck.peek) * (1 - deck.hush)
      gradient: Gradient {
        GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.66) }
        GradientStop { position: 0.13; color: Qt.rgba(0, 0, 0, 0.32) }
        GradientStop { position: 0.24; color: Qt.rgba(0, 0, 0, 0.06) }
        GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0) }
        GradientStop { position: 0.78; color: Qt.rgba(0, 0, 0, 0.18) }
        GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.6) }
      }
    }
    // Dimmed behind a chosen card.
    Rectangle { anchors.fill: parent; color: "black"; visible: opacity > 0; opacity: 0.55 * deck.spot * deck.shown }

    // The wheel browses wherever it turns; a click on the picture peeks.
    MouseArea {
      property real acc: 0
      anchors.fill: parent
      enabled: !deck.choosing
      onClicked: { if (deck.settingsOpen) deck.settingsOpen = false; else deck.peekKept = !deck.peekKept; keys.forceActiveFocus() }
      onWheel: function(w) {
        var d = w.angleDelta.y || w.angleDelta.x
        acc += d
        while (Math.abs(acc) >= 120) { deck.go(deck.target + (acc > 0 ? -1 : 1)); acc -= acc > 0 ? 120 : -120 }
        if (Math.abs(d) >= 120) acc = 0
      }
    }

    // ── The deck ──
    Item {
      id: table
      anchors.fill: parent
      opacity: deck.shown

      // Drag anywhere to turn the deck.
      DragHandler {
        id: drag
        property real from: 0
        target: null
        yAxis.enabled: false
        enabled: !deck.choosing && deck.count > 0
        onActiveChanged: {
          if (active) { posAnim.stop(); from = deck.pos }
          else {
            // A flick carries on a little.
            var v = centroid.velocity.x / (deck.stepN * deck.handR)
            deck.go(Math.round(deck.pos - v * 0.2))
          }
        }
        onActiveTranslationChanged: {
          if (!active || deck.count === 0) return
          deck.pos = Math.max(-0.45, Math.min(deck.count - 0.55, from - activeTranslation.x / (deck.stepN * deck.handR)))
          var i = Math.max(0, Math.min(deck.count - 1, Math.round(deck.pos)))
          if (i !== deck.target) { deck.target = i; deck._frontBefore = deck.list[i] }
        }
      }

      Repeater {
        id: hand
        model: deck.slots
        Item {
          id: slot
          required property int index
          // The card this slot holds: the one nearest the deck's position of
          // those it can hold (every `slots`-th), so as the deck turns each
          // slot takes a new card out of sight.
          readonly property int idx: index + deck.slots * Math.round((deck.pos - index) / deck.slots)
          readonly property real d: idx - deck.pos
          readonly property real ad: Math.abs(d)
          readonly property bool live: idx >= 0 && idx < deck.count && ad < deck.side + 1
          readonly property string file: live ? deck.list[idx] : ""
          readonly property bool lifted: deck.choosing && file === deck.chosen
          // 1 for the card in front.
          readonly property real near: Math.max(0, 1 - ad)
          readonly property real dealt: {
            var t = Math.max(0, Math.min(1, deck.deal * (1 + 0.09 * deck.side) - 0.09 * ad))
            return 1 - Math.pow(1 - t, 3)
          }
          readonly property real theta: (d < 0 ? -1 : 1) * (Math.min(ad, 1) * deck.step1 + Math.max(0, ad - 1) * deck.stepN)
          property real hoverLift: card.hovered && near < 0.5 ? 20 * deck.u : 0
          Behavior on hoverLift { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
          readonly property real r: deck.handR + deck.lift * near + hoverLift
          // Below its place while dealt or peeking.
          readonly property real lower: (1 - dealt) * (deck.cardH * 1.35 + 140 * deck.u) + deck.peek * (deck.cardH * 1.25 + 120 * deck.u)

          width: deck.cardW
          height: deck.cardH
          x: deck.pivotX + r * Math.sin(theta) - width / 2
          y: deck.pivotY - r * Math.cos(theta) - height / 2 + lower
          rotation: (theta + (1 - dealt) * (d < 0 ? -0.1 : 0.1)) * 180 / Math.PI
          scale: 1 + (deck.frontScale - 1) * near
          z: 100 - ad
          opacity: Math.max(0, Math.min(1, deck.side + 1 - ad))
          visible: live && opacity > 0.01 && y < deck.height && !lifted

          SwatchCard {
            id: card
            anchors.fill: parent
            u: deck.u
            pictures: slot.live ? deck.picturesOf(slot.file) : []
            video: !deck.themes && slot.live && Walls.isVideo(slot.file)
            cycling: deck.themes && slot.live && root.opened && slot.ad < deck.side
            roles: slot.live ? deck.rolesOf(slot.file) : null
            front: slot.near
            dim: Math.min(0.3, Math.max(0, slot.ad - 0.6) * 0.065)
            current: deck.isInUse(slot.file)
            favourite: !deck.themes && slot.live && Walls.isFav(slot.file)
            title: slot.live ? deck.nameOf(slot.file) : ""
            meta: slot.live ? deck.metaOf(slot.file) : ""
            onClicked: { if (slot.idx === deck.target) deck.pickCurrent(); else deck.go(slot.idx); keys.forceActiveFocus() }
            onDoubleClicked: { deck.place(slot.idx); deck.pickCurrent() }
          }
        }
      }
    }

    // ── Glass: the picker's controls, in the front card's colours ──
    component Glass: Rectangle {
      color: Tk.alpha(tint.surface, 0.8)
      border.width: 1
      border.color: Tk.alpha(tint.ink, 0.12)
      radius: Tk.rounded ? 20 * deck.u : 0
    }
    // A row of choices in a glass pill.
    component Segments: Glass {
      id: segs
      property var options: []
      property string value
      signal picked(string key)
      width: segRow.implicitWidth + 8 * deck.u
      height: 40 * deck.u
      Row {
        id: segRow
        anchors.centerIn: parent
        spacing: 2 * deck.u
        Repeater {
          model: segs.options
          Rectangle {
            id: seg
            required property var modelData
            readonly property bool current: segs.value === modelData.key
            width: segLabel.implicitWidth + 28 * deck.u
            height: 32 * deck.u
            radius: Tk.rounded ? 16 * deck.u : 0
            color: current ? tint.accent : segMouse.containsMouse ? Tk.alpha(tint.ink, 0.08) : "transparent"
            Row {
              id: segLabel
              anchors.centerIn: parent
              spacing: 6 * deck.u
              Icon { anchors.verticalCenter: parent.verticalCenter; visible: !!seg.modelData.icon; name: seg.modelData.icon || ""; filled: seg.current; size: 17 * deck.u; color: seg.current ? tint.accentInk : tint.muted }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: seg.modelData.label
                font.family: Tk.font; font.pixelSize: 13 * deck.u; font.weight: Font.DemiBold
                color: seg.current ? tint.accentInk : tint.ink
                textFormat: Text.PlainText
              }
            }
            MouseArea { id: segMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { segs.picked(seg.modelData.key); keys.forceActiveFocus() } }
          }
        }
      }
    }
    component RoundButton: Rectangle {
      id: rb
      property string icon
      property bool checked: false
      property color glyph: checked ? tint.accentInk : tint.ink
      property bool filledIcon: false
      signal clicked()
      width: 40 * deck.u; height: 40 * deck.u
      radius: Tk.rounded ? height / 2 : 0
      color: rb.checked ? (rbMouse.containsMouse ? Qt.lighter(tint.accent, 1.08) : tint.accent)
        : rbMouse.containsMouse ? Tk.alpha(tint.surface, 0.95) : Tk.alpha(tint.surface, 0.8)
      border.width: rb.checked ? 0 : 1
      border.color: Tk.alpha(tint.ink, 0.12)
      Icon { anchors.centerIn: parent; anchors.verticalCenterOffset: 1; name: rb.icon; filled: rb.filledIcon; size: 19 * deck.u; color: rb.glyph }
      MouseArea { id: rbMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { rb.clicked(); if (!deck.settingsOpen) keys.forceActiveFocus() } }
    }

    // ── Above the card in front: what Enter does ──
    Row {
      id: actions
      readonly property bool active: deck.isInUse(deck.front)
      readonly property bool fav: !deck.themes && !!deck.front && Walls.isFav(deck.front)
      anchors.horizontalCenter: parent.horizontalCenter
      y: deck.frontTop - height - 20 * deck.u + (1 - deck.deal) * 60 * deck.u + deck.peek * 40 * deck.u
      spacing: 8 * deck.u
      visible: deck.count > 0 && opacity > 0.05
      opacity: deck.shown * Math.max(0, deck.deal * 1.6 - 0.6) * (1 - deck.peek) * (1 - deck.hush)

      RoundButton {
        visible: !deck.themes
        icon: "favorite"
        filledIcon: actions.fav
        glyph: actions.fav ? "#ff5c7a" : tint.ink
        onClicked: deck.toggleFavourite()
      }
      Rectangle {
        id: setButton
        width: setRow.implicitWidth + 32 * deck.u
        height: 40 * deck.u
        radius: Tk.rounded ? height / 2 : 0
        color: actions.active ? Tk.alpha(tint.surface, 0.82) : setMouse.containsMouse ? Qt.lighter(tint.accent, 1.08) : tint.accent
        border.width: actions.active ? 1 : 0
        border.color: Tk.alpha(tint.ink, 0.14)
        Row {
          id: setRow
          anchors.centerIn: parent
          spacing: 8 * deck.u
          Icon { anchors.verticalCenter: parent.verticalCenter; name: actions.active ? "check_circle" : deck.themes ? "palette" : "wallpaper"; filled: actions.active; size: 19 * deck.u; color: actions.active ? tint.accent : tint.accentInk }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: actions.active ? (deck.themes ? "Theme in use" : "On your desktop") : deck.themes ? "Apply theme" : "Set wallpaper"
            font.family: Tk.font; font.pixelSize: 14 * deck.u; font.weight: Font.DemiBold
            color: actions.active ? tint.ink : tint.accentInk
            textFormat: Text.PlainText
          }
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: !actions.active
            width: enterKey.implicitWidth + 10 * deck.u; height: 20 * deck.u
            radius: Tk.rounded ? 6 * deck.u : 0
            color: Tk.alpha(tint.accentInk, 0.14)
            Text { id: enterKey; anchors.centerIn: parent; text: "⏎"; font.family: Tk.font; font.pixelSize: 12 * deck.u; font.weight: Font.Bold; color: tint.accentInk; textFormat: Text.PlainText }
          }
        }
        MouseArea { id: setMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: actions.active ? Qt.ArrowCursor : Qt.PointingHandCursor; onClicked: deck.pickCurrent() }
      }
    }

    // ── The head: title, mode, sources, order, the ribbon ──
    Item {
      id: head
      x: 40 * deck.u
      y: 28 * deck.u - (1 - deck.shown) * 18 * deck.u - Math.max(deck.peek, deck.hush) * 24 * deck.u
      width: parent.width - 80 * deck.u
      height: 44 * deck.u
      opacity: deck.shown * (1 - deck.peek) * (1 - deck.hush)
      visible: opacity > 0.01

      Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12 * deck.u
        Icon { anchors.verticalCenter: parent.verticalCenter; name: deck.themes ? "palette" : "style"; filled: true; size: 28 * deck.u; color: tint.accent }
        Column {
          anchors.verticalCenter: parent.verticalCenter
          Text { text: deck.themes ? "Themes" : "Wallpapers"; font.family: Tk.font; font.pixelSize: 21 * deck.u; font.weight: Font.Bold; color: "white"; textFormat: Text.PlainText }
          Text {
            text: deck.count === 0 ? "" : (deck.target + 1) + " of " + deck.count
              + (deck.sort === "colour" ? "  ·  by colour" : deck.sort === "newest" ? "  ·  newest first" : "  ·  by name")
              + (!deck.themes && deck.source === "theme" && Walls.themeName ? "  ·  " + Walls.themeName : "")
            font.family: Tk.font; font.pixelSize: 12 * deck.u
            color: Qt.rgba(1, 1, 1, 0.72)
            textFormat: Text.PlainText
          }
        }
      }

      Row {
        anchors.centerIn: parent
        spacing: 8 * deck.u
        Segments {
          options: [{ key: "wallpaper", label: "Wallpapers", icon: "photo_library" }, { key: "theme", label: "Themes", icon: "palette" }]
          value: deck.mode
          onPicked: function(key) { deck.setMode(key) }
        }
        Segments {
          visible: !deck.themes
          options: [
            { key: "theme", label: "This theme", icon: "format_paint" },
            { key: "all", label: "All themes", icon: "apps" },
            { key: "folder", label: "Folder", icon: "folder" },
            { key: "favourites", label: "Favourites  " + Walls.favourites.length, icon: "favorite" }
          ]
          value: deck.source
          onPicked: function(key) { deck.setSource(key) }
        }
      }

      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8 * deck.u
        Segments {
          anchors.verticalCenter: parent.verticalCenter
          options: [
            { key: "name", label: "Name", icon: "sort_by_alpha" },
            { key: "colour", label: "Colour", icon: "palette" },
            { key: "newest", label: "Newest", icon: "schedule" }
          ]
          value: deck.sort
          onPicked: function(key) { deck.setSort(key) }
        }
        RoundButton { anchors.verticalCenter: parent.verticalCenter; icon: "visibility"; checked: deck.peekKept; onClicked: deck.peekKept = !deck.peekKept }
        RoundButton {
          anchors.verticalCenter: parent.verticalCenter
          icon: "settings"
          checked: deck.settingsOpen
          onClicked: { deck.settingsOpen = !deck.settingsOpen; if (deck.settingsOpen) settingsCard.reset(); else keys.forceActiveFocus() }
        }
        RoundButton { anchors.verticalCenter: parent.verticalCenter; icon: "close"; onClicked: root.close() }
      }
    }

    Ribbon {
      id: ribbon
      x: head.x
      y: head.y + head.height + 16 * deck.u
      width: head.width
      u: deck.u
      opacity: head.opacity
      visible: opacity > 0.01 && deck.count > 0
      pos: deck.pos
      span: deck.side
      accent: tint.accent
      ink: tint.ink
      surface: tint.surface
      colors: { var l = deck.list, out = []; for (var i = 0; i < l.length; i++) { var r = deck.rolesOf(l[i]); out.push(r ? r.primary : "") } return out }
      favourites: { if (deck.themes) return []; Walls.favourites; var l = deck.list, out = []; for (var i = 0; i < l.length; i++) if (Walls.isFav(l[i])) out.push(i); return out }
      activeIndex: deck.list.indexOf(deck.inUse)
      thumbs: { Palettes.revision; return deck.themes ? deck.list.map(function(t) { return Themes.previewOf(t) }) : deck.list.map(function(p) { return Walls.isVideo(p) ? "" : (Palettes.thumbOf(p) || p) }) }
      names: deck.list.map(function(p) { return deck.nameOf(p) })
      onJump: function(i, instant) { if (instant) deck.place(i); else deck.go(i) }
    }

    // Under the ribbon: the keys.
    Glass {
      anchors.horizontalCenter: parent.horizontalCenter
      y: ribbon.y + ribbon.height + 14 * deck.u
      visible: deck.count > 0 && opacity > 0.01
      opacity: head.opacity
      width: hints.implicitWidth + 28 * deck.u
      height: 28 * deck.u
      color: Tk.alpha(tint.surface, 0.6)
      Text {
        id: hints
        anchors.centerIn: parent
        text: "←→ or wheel browse  ·  Enter set  ·  " + (deck.themes ? "" : "F favourite  ·  ") + "S sort  ·  R random  ·  Space peek  ·  "
          + (deck.themes ? "" : "Tab source  ·  ") + "T " + (deck.themes ? "wallpapers" : "themes") + "  ·  Esc close"
        font.family: Tk.font; font.pixelSize: 12 * deck.u
        color: Tk.alpha(tint.ink, 0.78)
        textFormat: Text.PlainText
      }
    }

    // Reading colours (the first time, or new wallpapers), under the ribbon
    // on the right.
    Glass {
      anchors.right: head.right
      y: ribbon.y + ribbon.height + 14 * deck.u
      visible: !deck.themes && Palettes.pending > 0 && !deck.settingsOpen && opacity > 0.01
      opacity: head.opacity
      width: readingRow.implicitWidth + 24 * deck.u
      height: 28 * deck.u
      color: Tk.alpha(tint.surface, 0.6)
      Row {
        id: readingRow
        anchors.centerIn: parent
        spacing: 8 * deck.u
        Icon {
          id: spin
          anchors.verticalCenter: parent.verticalCenter
          name: "progress_activity"; size: 15 * deck.u; color: tint.accent
          RotationAnimation on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: spin.visible && root.opened }
        }
        Text { anchors.verticalCenter: parent.verticalCenter; text: "Reading colours  ·  " + Palettes.pending + " left"; font.family: Tk.font; font.pixelSize: 12 * deck.u; color: tint.muted; textFormat: Text.PlainText }
      }
    }

    // The gear's settings, under the head on the right.
    SettingsCard {
      id: settingsCard
      anchors.right: head.right
      y: head.y + head.height + 12 * deck.u
      u: deck.u
      visible: deck.settingsOpen && opacity > 0.01
      opacity: head.opacity
      surface: tint.surface; ink: tint.ink; muted: tint.muted; accent: tint.accent; accentInk: tint.accentInk
      onDone: { deck.settingsOpen = false; keys.forceActiveFocus() }
    }

    // ── Nothing to deal ──
    Column {
      anchors.centerIn: parent
      spacing: 14 * deck.u
      visible: deck.count === 0 && root.opened && (deck.themes || deck.settled)
      opacity: deck.shown
      Icon {
        anchors.horizontalCenter: parent.horizontalCenter
        name: deck.themes ? "palette" : deck.source === "favourites" ? "heart_plus" : "hide_image"
        size: 44 * deck.u; color: Qt.rgba(1, 1, 1, 0.7)
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        horizontalAlignment: Text.AlignHCenter
        text: deck.themes ? "No themes found. Press T for wallpapers."
          : deck.source === "favourites" ? "No favourites yet. Press F on a card to keep it here."
          : deck.source === "folder" ? "No pictures in " + Walls.folder + "."
          : "No wallpapers here. Press Tab for another source."
        font.family: Tk.font; font.pixelSize: 14 * deck.u
        color: Qt.rgba(1, 1, 1, 0.85)
        textFormat: Text.PlainText
      }
      Glass {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: !deck.themes && deck.source === "folder"
        width: folderRow.implicitWidth + 28 * deck.u; height: 36 * deck.u
        Row {
          id: folderRow
          anchors.centerIn: parent; spacing: 8 * deck.u
          Icon { anchors.verticalCenter: parent.verticalCenter; name: "folder_open"; size: 17 * deck.u; color: tint.ink }
          Text { anchors.verticalCenter: parent.verticalCenter; text: "Choose another folder"; font.family: Tk.font; font.pixelSize: 13 * deck.u; font.weight: Font.DemiBold; color: tint.ink; textFormat: Text.PlainText }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { deck.settingsOpen = true; settingsCard.reset() } }
      }
    }

    // While peeking: how to get back.
    Glass {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 30 * deck.u
      visible: opacity > 0.01
      opacity: deck.peekKept ? deck.peek * deck.shown : 0
      width: peekRow.implicitWidth + 28 * deck.u
      height: 36 * deck.u
      Row {
        id: peekRow
        anchors.centerIn: parent
        spacing: 10 * deck.u
        Text { anchors.verticalCenter: parent.verticalCenter; text: deck.nameOf(deck.front); font.family: Tk.font; font.pixelSize: 13 * deck.u; font.weight: Font.DemiBold; color: tint.ink; textFormat: Text.PlainText }
        Text { anchors.verticalCenter: parent.verticalCenter; text: "←→ browse  ·  Space or Esc: back to the deck"; font.family: Tk.font; font.pixelSize: 12 * deck.u; color: tint.muted; textFormat: Text.PlainText }
      }
    }

    // ── The chosen card ──
    // Out of the hand: placed where it was in the hand, then moved by
    // riseAnim and bloomAnim.
    Item {
      id: flight
      // Each 0..1: the glow behind the card, the ring going out from it, its
      // pulse as it's set, the card gone from round its picture, the picture
      // grown into the wallpaper. And the light across the picture.
      property real glow: 0
      property real ring: 0
      property real pulse: 0
      property real fade: 0
      property real bloom: 0
      property real shine: -1
      z: 20
      width: deck.cardW
      height: deck.cardH
      visible: deck.choosing
      opacity: deck.shown

      RectangularShadow {
        anchors.fill: chosenCard
        radius: chosenCard.radius
        blur: (34 + 22 * flight.pulse) * deck.u
        spread: 5 * deck.u * flight.pulse
        color: Tk.alpha(chosenCard.cAccent, 0.6)
        visible: opacity > 0.01
        opacity: flight.glow * (1 - flight.fade)
      }
      // Goes out from the card as it's set.
      Rectangle {
        readonly property real grow: 64 * deck.u * flight.ring
        anchors.centerIn: parent
        width: parent.width + grow * 2
        height: parent.height + grow * 2
        radius: chosenCard.radius + grow
        antialiasing: true
        color: "transparent"
        border.width: Math.max(1, 2.4 * deck.u * (1 - 0.6 * flight.ring))
        border.color: chosenCard.cAccent
        visible: opacity > 0.01
        opacity: flight.ring > 0 && flight.ring < 1 ? Math.pow(1 - flight.ring, 1.3) : 0
      }
      SwatchCard {
        id: chosenCard
        anchors.fill: parent
        scale: 1 + 0.035 * flight.pulse
        opacity: 1 - flight.fade
        u: deck.u
        pictures: deck.picturesOf(deck.chosen)
        video: !deck.themes && Walls.isVideo(deck.chosen)
        roles: deck.chosen ? deck.rolesOf(deck.chosen) : null
        front: 1
        current: deck.chosenSet
        favourite: !deck.themes && !!deck.chosen && Walls.isFav(deck.chosen)
        title: deck.chosen ? deck.nameOf(deck.chosen) : ""
        meta: deck.metaOf(deck.chosen)
        shine: flight.shine
      }
    }
    // The picture, from its place on the chosen card to the whole screen:
    // the wallpaper.
    Rounded {
      id: bloomPic
      readonly property rect pr: chosenCard.pictureRect
      readonly property real k: flight.scale
      readonly property real cx: flight.x + flight.width / 2
      readonly property real cy: flight.y + flight.height / 2
      readonly property real e: flight.bloom
      z: 21
      visible: deck.choosing && e > 0
      opacity: deck.shown
      x: (cx + (pr.x - flight.width / 2) * k) * (1 - e)
      y: (cy + (pr.y - flight.height / 2) * k) * (1 - e)
      width: pr.width * k + (deck.width - pr.width * k) * e
      height: pr.height * k + (deck.height - pr.height * k) * e
      radius: chosenCard.thumbRadius * k * (1 - e)
      Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        source: deck.choosing ? deck.bloomOf(deck.chosen) : ""
        sourceSize.width: deck.width; sourceSize.height: deck.height
      }
    }

    // ── Keys ──
    Item {
      id: keys
      focus: true
      Keys.onPressed: function(e) {
        var k = e.key
        if (deck.choosing) { e.accepted = true; return }
        if (k === Qt.Key_Escape) {
          if (e.isAutoRepeat) {}
          else if (deck.settingsOpen) deck.settingsOpen = false
          else if (deck.peekKept) deck.peekKept = false
          else root.close()
        }
        else if (k === Qt.Key_Left || k === Qt.Key_Up || k === Qt.Key_H) deck.go(deck.target - 1)
        else if (k === Qt.Key_Right || k === Qt.Key_Down || k === Qt.Key_L) deck.go(deck.target + 1)
        else if (k === Qt.Key_Home) deck.go(0)
        else if (k === Qt.Key_End) deck.go(deck.count - 1)
        else if (k === Qt.Key_PageUp) deck.go(deck.target - 8)
        else if (k === Qt.Key_PageDown) deck.go(deck.target + 8)
        else if (k === Qt.Key_Return || k === Qt.Key_Enter) deck.pickCurrent()
        else if (k === Qt.Key_Space) {
          if (!e.isAutoRepeat) { deck.peekHeld = true; deck.peekPressedAt = Date.now() }
        }
        else if (k === Qt.Key_F) deck.toggleFavourite()
        else if (k === Qt.Key_S) deck.setSort(deck.sorts[(deck.sorts.indexOf(deck.sort) + 1) % 3])
        else if (k === Qt.Key_R) { if (deck.count > 1) { var r = deck.target; while (r === deck.target) r = Math.floor(Math.random() * deck.count); deck.go(r) } }
        else if (k === Qt.Key_T) deck.setMode(deck.themes ? "wallpaper" : "theme")
        else if (k === Qt.Key_Tab || k === Qt.Key_Backtab) {
          if (!deck.themes) deck.setSource(root.sources[(root.sources.indexOf(deck.source) + (k === Qt.Key_Tab ? 1 : 3)) % 4])
        }
        else return
        e.accepted = true
      }
      // Space: held, the deck steps aside while it's down; tapped, it stays
      // aside until Space or Esc again.
      Keys.onReleased: function(e) {
        if (e.key !== Qt.Key_Space || e.isAutoRepeat || deck.choosing) return
        deck.peekHeld = false
        if (Date.now() - deck.peekPressedAt < 250) deck.peekKept = !deck.peekKept
        e.accepted = true
      }
    }
  }
}
