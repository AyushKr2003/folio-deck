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
  property var data: ({})            // id -> { title, preview, mode, origin, mtime, roles }
  property string current: ""

  function get(id) { return data[id] || null }
  function rolesOf(id) { var t = get(id); return t ? t.roles : null }
  function previewOf(id) { var t = get(id); return t ? t.preview : "" }
  function titleOf(id) { var t = get(id); return t ? t.title : id }
  function set(id) {
    current = id
    Quickshell.execDetached(["omarchy-theme-set", id])
  }
  function scan() { proc.running = false; proc.running = true }
  Component.onCompleted: scan()

  Process {
    id: proc
    command: [root.script]
    stdout: StdioCollector {
      onStreamFinished: {
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
