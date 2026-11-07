pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../core/Palette.js" as Palette

// Palettes for Folio Deck's cards, from scripts/palette. Worked out
// only while the deck asks (want()), the cards in view first, three at a time
// at low priority, and kept in ~/.cache/folio-deck/palettes.json keyed
// by file and mtime, so each image is read once. Each read also writes a
// small JPEG of the picture to ~/.cache/folio-deck/thumbs/, which the cards
// show instead of the full picture.
Singleton {
  id: root
  readonly property string cachePath: Store.cacheDir + "/palettes.json"
  readonly property string script: Qt.resolvedUrl("../scripts/palette").toString().replace(/^(file|qs):\/\//, "")
  property var cache: ({})          // path -> { mtime, w, h, fmt, size, roles, thumb }
  property int revision: 0
  property var queue: []
  property var mtimes: ({})
  // How many are still to read (queued or being read), for "Reading colours".
  readonly property int pending: queue.length + (w0.running ? 1 : 0) + (w1.running ? 1 : 0) + (w2.running ? 1 : 0)

  function info(path) { revision; return cache[path] || null }
  function rolesOf(path) { var i = info(path); return i ? i.roles : null }
  // The small copy of a picture, once read ("" until then).
  function thumbOf(path) { var i = info(path); return i && i.thumb ? i.thumb : "" }
  function thumbPath(path, mtime) { return Store.cacheDir + "/thumbs/" + Qt.md5(path + ":" + mtime) + ".jpg" }

  // The deck hands over the files it shows, nearest the front first.
  function want(paths, mtimeOf) {
    var q = []
    for (var i = 0; i < paths.length; i++) {
      var p = paths[i]
      if (!p) continue
      var m = mtimeOf ? mtimeOf(p) : 0
      mtimes[p] = m
      var c = cache[p]
      if (!c || (m && c.mtime !== m) || c.thumb === undefined) q.push(p)
    }
    queue = q
    pump()
  }

  function pump() {
    var workers = [w0, w1, w2], q = queue.slice()
    for (var i = 0; i < workers.length && q.length; i++) {
      if (workers[i].running) continue
      var next = q.shift()
      if (!next) { i--; continue }
      workers[i].file = next
      workers[i].command = [root.script, next, root.thumbPath(next, root.mtimes[next] || 0)]
      workers[i].running = true
    }
    queue = q
  }

  function take(line) {
    try {
      var j = JSON.parse(line)
      var next = Object.assign({}, cache)
      next[j.file] = { mtime: mtimes[j.file] || 0, w: j.w, h: j.h, fmt: j.fmt, size: j.size, roles: Palette.roles(j.colors), thumb: j.thumb || "" }
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
