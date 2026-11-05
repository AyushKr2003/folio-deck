pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../core/Palette.js" as Palette

// Palettes for Folio Deck's cards, from scripts/palette. Worked out
// only while the deck asks (want()), the cards in view first, three at a time
// at low priority, and kept in ~/.cache/folio-deck/palettes.json keyed
// by file and mtime, so each image is read once.
Singleton {
  id: root
  readonly property string cachePath: Store.cacheDir + "/palettes.json"
  readonly property string script: Qt.resolvedUrl("../scripts/palette").toString().replace(/^(file|qs):\/\//, "")
  property var cache: ({})          // path -> { mtime, w, h, fmt, size, roles }
  property int revision: 0
  property var queue: []
  property var mtimes: ({})

  function info(path) { revision; return cache[path] || null }
  function rolesOf(path) { var i = info(path); return i ? i.roles : null }

  // The deck hands over the files it shows, nearest the front first.
  function want(paths, mtimeOf) {
    var q = []
    for (var i = 0; i < paths.length; i++) {
      var p = paths[i], m = mtimeOf ? mtimeOf(p) : 0
      mtimes[p] = m
      var c = cache[p]
      if (!c || (m && c.mtime !== m)) q.push(p)
    }
    queue = q
    pump()
  }

  function pump() {
    var workers = [w0, w1, w2]
    for (var i = 0; i < workers.length && queue.length; i++) {
      if (workers[i].running) continue
      var next = queue.shift()
      workers[i].file = next
      workers[i].command = [root.script, next]
      workers[i].running = true
    }
  }

  function take(line) {
    try {
      var j = JSON.parse(line)
      var next = Object.assign({}, cache)
      next[j.file] = { mtime: mtimes[j.file] || 0, w: j.w, h: j.h, fmt: j.fmt, size: j.size, roles: Palette.roles(j.colors) }
      cache = next
      revision++
      saver.restart()
    } catch (e) {}
  }

  component Worker: Process {
    property string file
    stdout: SplitParser { onRead: function(line) { root.take(line) } }
    onExited: root.pump()
  }
  Worker { id: w0 }
  Worker { id: w1 }
  Worker { id: w2 }

  Timer { id: saver; interval: 1500; onTriggered: { Quickshell.execDetached(["mkdir", "-p", Store.cacheDir]); store.setText(JSON.stringify(root.cache)) } }
  FileView {
    id: store
    path: root.cachePath
    printErrors: false
    onLoaded: { try { root.cache = JSON.parse(text()) || {}; root.revision++ } catch (e) {} }
  }
}
