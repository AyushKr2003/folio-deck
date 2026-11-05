pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Wallpapers for Folio Deck, Omarchy's way: the current theme's backgrounds (yours in
// ~/.config/omarchy/backgrounds/<theme>/ and the theme's own), every
// installed theme's, or a folder of your own (the "folder" setting).
// Setting one runs `omarchy theme bg set`, which also plays Omarchy's
// transition. Favourites are kept in Folio Deck's settings.
Singleton {
  id: root
  property string source: "theme"          // theme | all | folder
  // Emitted when a scan has filled files, meta, current and themeName.
  signal scanned()
  property var files: []
  property var meta: ({})                  // path -> { mtime, size }
  property string current: ""
  property string themeName: ""
  readonly property string folder: Store.get("folder")
  readonly property var favourites: Store.get("favourites")

  function isFav(f) { return favourites.indexOf(f) >= 0 }
  function toggleFav(f) {
    var l = favourites.slice(), i = l.indexOf(f)
    if (i >= 0) l.splice(i, 1); else l.push(f)
    Store.set("favourites", l)
  }
  function isVideo(f) { return /\.(mp4|m4v|mov|webm|mkv|avi)$/i.test(f) }
  function set(f) {
    current = f
    Quickshell.execDetached(["omarchy-theme-bg-set", f])
  }
  function scan() { proc.running = false; proc.running = true }
  onSourceChanged: scan()
  Component.onCompleted: scan()
  onFolderChanged: if (source === "folder") scan()

  readonly property string script:
    "st=$HOME/.local/state/omarchy/current; t=$(cat $st/theme.name 2>/dev/null); echo \"#theme $t\"; echo \"#current $(readlink -f $st/background)\";" +
    "case $1 in theme) d=(\"$HOME/.config/omarchy/backgrounds/$t\" \"$st/theme/backgrounds\");;" +
    " all) d=(\"$HOME\"/.config/omarchy/backgrounds/* \"$OMARCHY_PATH\"/themes/*/backgrounds \"$HOME\"/.config/omarchy/themes/*/backgrounds);;" +
    " folder) d=(\"$2\");; esac;" +
    "find -L \"${d[@]}\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \\) -printf '%T@\\t%s\\t%p\\n' 2>/dev/null | sort -t$'\\t' -k3 -u | head -2000"
  Process {
    id: proc
    command: ["bash", "-c", root.script, "_", root.source, root.folder]
    stdout: StdioCollector {
      onStreamFinished: {
        var out = [], meta = {}
        String(text).split("\n").forEach(function(l) {
          if (l.indexOf("#theme ") === 0) root.themeName = l.slice(7)
          else if (l.indexOf("#current ") === 0) root.current = l.slice(9)
          else if (l) {
            var p = l.split("\t")
            if (p.length < 3) return
            var path = p.slice(2).join("\t")
            meta[path] = { mtime: Math.round(Number(p[0])), size: Number(p[1]) }
            out.push(path)
          }
        })
        root.meta = meta
        root.files = out
        root.scanned()
      }
    }
  }
}
