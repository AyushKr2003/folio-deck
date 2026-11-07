import QtQuick
import ".."

// The picker's full-screen preview: the card in front at the size it would
// have on the desktop. Two images take turns: the one on screen and the one
// loading over it, which fades in once it's ready. Only the latest picture
// asked for is ever faded in, and a fade in progress finishes first, so the
// screen is never left black between two pictures. A small copy of the
// picture (`quick`), when there is one, covers the wait for the full one.
Item {
  id: backdrop

  // The picture on screen (or on its way).
  property string wanted: ""
  property string quickWanted: ""
  property Image onTop: a
  readonly property bool ready: onTop.status === Image.Ready && onTop.source.toString() === wanted

  function show(url, quick) {
    quickWanted = quick || ""
    if (url === wanted) return
    wanted = url
    if (!fade.running) next()
  }
  function next() {
    if (onTop.source.toString() === wanted) return
    var back = onTop === a ? b : a
    back.opacity = 0
    if (back.source.toString() === wanted && back.status === Image.Ready) { loaded(back); return }
    back.source = wanted
    if (!wanted) { fade.target = back; fade.restart() }
  }
  function loaded(img) {
    if (img === onTop || img.source.toString() !== wanted) return
    fade.target = img
    fade.restart()
  }

  component Pic: Image {
    anchors.fill: parent
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    smooth: true
    cache: false
    sourceSize.width: backdrop.width
    sourceSize.height: backdrop.height
    opacity: 0
    onStatusChanged: if (status === Image.Ready) backdrop.loaded(this)
  }
  Pic { id: a; z: 0 }
  Pic { id: b; z: 1 }

  // The small copy, over both, until the full picture is up.
  Image {
    id: quickPic
    z: 3
    anchors.fill: parent
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    source: backdrop.quickWanted
    opacity: status === Image.Ready && !backdrop.ready && backdrop.wanted !== "" ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Tk.ms(200) } }
  }

  NumberAnimation {
    id: fade
    property: "opacity"; to: 1
    duration: Tk.ms(260); easing.type: Easing.OutCubic
    onStarted: target.z = 2
    onFinished: {
      var old = backdrop.onTop
      backdrop.onTop = target
      target.z = 0
      old.opacity = 0
      old.z = 1
      // Asked for another while this one faded.
      backdrop.next()
    }
  }
}
