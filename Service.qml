import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

Item {
    id: root
    property var shell: null
    property string folder: ""
    property int minutes: 5
    property bool paused: false
    property string fit: "normal"
    property var wallpapers: []
    property int count: 0
    readonly property string current: wallpapers.length ? wallpapers[0] : ""
    property string error: ""
    readonly property string helper: Qt.resolvedUrl("slideshow.py").toString().replace(/^file:\/\//, "")

    function setFit(mode) {
        if (["normal", "vertical", "horizontal", "stretch"].indexOf(mode) < 0 || control.running) return
        control.command = ["python3", helper, "fit", "--fit", mode]
        control.running = true
    }
    function reloadConfig() { config.reload() }
    function openThemeSelector() {
        var payload = JSON.stringify({ source: "themes" })
        if (!shell || !shell.summon("omarchy.image-picker", payload))
            Util.execArgv(["omarchy-shell", "shell", "summon", "omarchy.image-picker", payload])
    }
    function next() {
        if (!folder) { configure(); return }
        if (advance.running) return
        advance.command = ["python3", helper, "next", "--current", current, "--screens", String(Quickshell.screens.length)]
        advance.running = true
    }
    function configure() {
        if (control.running) return
        control.command = ["python3", helper, "configure"]
        control.running = true
    }
    function toggle() {
        if (!folder) { configure(); return }
        if (control.running) return
        control.command = ["python3", helper, "toggle"]
        control.running = true
    }
    FileView {
        id: config
        path: Quickshell.env("HOME") + "/.config/omarchy/wallpaper-slideshow.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                var data = JSON.parse(text())
                var changed = root.folder !== String(data.folder || "")
                root.folder = String(data.folder || "")
                root.minutes = Math.max(1, Math.min(1440, Number(data.minutes) || 5))
                root.paused = data.paused === true
                root.fit = ["normal", "vertical", "horizontal", "stretch"].indexOf(data.fit) >= 0 ? data.fit : "normal"
                root.error = ""
                if (changed && root.folder) Qt.callLater(root.next)
                if (!root.folder) root.wallpapers = []
            } catch (e) { root.error = "Invalid slideshow configuration" }
        }
    }
    Timer {
        id: timer
        interval: root.minutes * 60000
        repeat: true
        running: root.folder !== "" && !root.paused && root.error === ""
        onTriggered: root.next()
    }
    Process {
        id: advance
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text)
                    root.wallpapers = data.paths
                    root.count = data.count
                    root.error = ""
                } catch (e) {}
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.error = text.trim() }
        onExited: function(code) { if (code !== 0 && !root.error) root.error = "Could not set wallpaper" }
    }
    Process { id: control; onExited: root.reloadConfig() }
    Connections {
        target: Quickshell
        function onScreensChanged() { if (root.folder) root.next() }
    }
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            readonly property int screenIndex: Quickshell.screens.indexOf(modelData)
            readonly property string wallpaper: root.wallpapers[screenIndex] || ""
            visible: wallpaper !== ""
            anchors { top: true; bottom: true; left: true; right: true }
            // Bottom sits above the stock background and below regular windows.
            // Removing this plugin reveals the normal Omarchy wallpaper again.
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "omarchy-wallpaper-slideshow"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WallpaperSurface {
                anchors.fill: parent
                fit: root.fit
                path: wallpaper
                pixelRatio: modelData.devicePixelRatio
                onLoadFailed: function(path) { root.error = "Could not load wallpaper: " + path }
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onDoubleClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) root.openThemeSelector()
                    else root.next()
                    mouse.accepted = true
                }
            }
        }
    }
    IpcHandler {
        target: "wallpaper-slideshow"
        function setFit(mode: string): void { root.setFit(mode) }
        function next(): void { root.next() }
        function configure(): void { root.configure() }
        function toggle(): void { root.toggle() }
        function status(): string {
            return JSON.stringify({folder: root.folder, minutes: root.minutes, paused: root.paused,
                                   fit: root.fit, wallpapers: root.wallpapers, count: root.count, error: root.error})
        }
    }
}
