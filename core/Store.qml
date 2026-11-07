pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// What Folio Deck remembers: favourites, the last mode, source and sort,
// your own folder, and whether a chosen card grows into the wallpaper. Kept in ~/.config/folio-deck/settings.json (watched, so a hand
// edit applies at once).
Singleton {
  id: root
  readonly property string home: Quickshell.env("HOME")
  readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/folio-deck"
  readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/folio-deck"
  property var doc: ({})
  property int revision: 0
  readonly property var defaults: ({ favourites: [], mode: "wallpaper", source: "theme", sort: "name", folder: home + "/Pictures/Wallpapers", animateChoice: true })
  function get(k) { revision; return doc[k] !== undefined ? doc[k] : defaults[k] }
  function set(k, v) { var n = Object.assign({}, doc); n[k] = v; doc = n; revision++; saver.restart() }
  Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", dir, cacheDir])
  Timer { id: saver; interval: 400; onTriggered: file.setText(JSON.stringify(root.doc, null, 2) + "\n") }
  FileView {
    id: file
    path: root.dir + "/settings.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { var v = JSON.parse(text()); if (JSON.stringify(v) !== JSON.stringify(root.doc)) { root.doc = v; root.revision++ } } catch (e) {} }
  }
}
