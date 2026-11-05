pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Omarchy themes for Folio Deck's theme cards, from scripts/themes: each
// theme's preview picture, light/dark mode, origin and five colour chips.
// Applying one runs `omarchy-theme-set`, which retints the whole desktop.
Singleton {
  id: root
  readonly property string script: Qt.resolvedUrl("../scripts/themes").toString().replace(/^(file|qs):\/\//, "")
  // Emitted when a scan has filled names, data and current.
  signal scanned()
  property var names: []
  property var data: ({})            // id -> { title, preview, backgrounds, mode, origin, mtime, roles }
  property string current: ""

  function get(id) { return data[id] || null }
  function rolesOf(id) { var t = get(id); return t ? t.roles : null }
  function previewOf(id) { var t = get(id); return t ? t.preview : "" }
  // What the card shows: the preview, then each of the theme's wallpapers.
  function picturesOf(id) {
    var t = get(id)
    if (!t) return []
    return (t.preview ? [t.preview] : []).concat(t.backgrounds || [])
  }
  function titleOf(id) { var t = get(id); return t ? t.title : id }
  function set(id) {
    current = id
    Quickshell.execDetached(["omarchy-theme-set", id])
  }
  // A scan asked for while one runs waits for it, rather than killing it:
  // a killed run can still hand over a partial list, and the deck would
  // settle on that (missing the card in use).
  property bool again: false
  function scan() { if (proc.running) again = true; else proc.running = true }
  Component.onCompleted: scan()

  Process {
    id: proc
    command: [root.script]
    onExited: if (root.again) { root.again = false; running = true }
    stdout: StdioCollector {
      onStreamFinished: {
        if (root.again) return
        var names = [], data = {}
        String(text).split("\n").forEach(function(l) {
          if (l.indexOf("#current ") === 0) root.current = l.slice(9)
          else if (l) {
            try { var t = JSON.parse(l); data[t.id] = t; names.push(t.id) } catch (e) {}
          }
        })
        root.data = data
        root.names = names
        root.scanned()
      }
    }
  }
}
