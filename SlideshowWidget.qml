import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui as Ui
import "TextSafety.js" as TextSafety

Ui.BarWidget {
    id: root
    moduleName: "seth.wallpaper-slideshow"
    readonly property var service: bar?.shell?.serviceFor(moduleName) || null
    property bool opened: false
    function open() { opened = true }
    function close() { opened = false }
    IpcHandler {
        target: "wallpaper-slideshow-controls"
        function open(): void { root.open() }
        function close(): void { root.close() }
        function status(): string {
            return JSON.stringify({opened: root.opened, serviceAvailable: root.service !== null})
        }
    }
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    Ui.WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: root.service?.paused ? "󰏤" : "󰸉"
        tooltipText: "OmaWallSwitcher" + (root.service?.folder ? "\n" + TextSafety.tooltip(root.service.folder) : "\nChoose a folder to start")
                     + (root.service?.error ? "\n" + TextSafety.tooltip(root.service.error) : "")
                     + "\nClick to open slideshow controls"
        onPressed: function(b) {
            if (!root.service) return
            if (b === Qt.RightButton) root.service.configure()
            else if (b === Qt.MiddleButton) root.service.toggle()
            else root.opened = !root.opened
        }
    }
    Ui.PopupCard {
        id: popup
        anchorItem: button
        bar: root.bar
        owner: root
        open: root.opened
        contentWidth: popup.fittedContentWidth(Style.space(300))
        contentHeight: popup.fittedContentHeight(column.implicitHeight)
        Column {
            id: column
            anchors.fill: parent
            spacing: Style.space(10)
            Text {
                text: "OmaWallSwitcher"
                textFormat: Text.PlainText
                color: root.bar.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
            }
            Text {
                width: parent.width
                textFormat: Text.PlainText
                text: root.service?.error || (root.service?.folder
                      ? root.service.folder + "\nEvery " + root.service.minutes + " min · "
                        + (root.service.paused ? "Paused" : "Playing")
                        + (root.service.count < 2 ? "\nAdd more images for different wallpapers." : "")
                      : "Choose an image folder to start.")
                wrapMode: Text.WrapAnywhere
                color: root.bar.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
            }
            Ui.Button {
                text: "Choose folder…"
                foreground: root.bar.foreground
                onClicked: { root.opened = false; root.service?.configure() }
            }
            Text {
                text: "Wallpaper fitting"
                textFormat: Text.PlainText
                color: root.bar.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
            }
            Grid {
                width: parent.width
                columns: 2
                spacing: Style.space(8)
                Repeater {
                    model: [
                        { value: "normal", label: "Normal" },
                        { value: "vertical", label: "Fit vertical" },
                        { value: "horizontal", label: "Fit horizontal" },
                        { value: "stretch", label: "Stretch" }
                    ]
                    Ui.Button {
                        required property var modelData
                        width: (parent.width - parent.spacing) / 2
                        text: modelData.label
                        foreground: root.bar.foreground
                        bordered: true
                        selected: (root.service?.fit || "normal") === modelData.value
                        onClicked: root.service?.setFit(modelData.value)
                    }
                }
            }
            Row {
                Ui.Button {
                    text: "Lock Explorer wallpapers"
                    foreground: root.bar.foreground
                    bordered: true
                    selected: root.service?.lockScreenSupport || false
                    onClicked: root.service?.setLockScreenSupport(!root.service.lockScreenSupport)
                }
            }
            Row {
                spacing: Style.space(8)
                Ui.Button {
                    text: root.service?.paused ? "Resume" : "Pause"
                    foreground: root.bar.foreground
                    enabled: !!root.service?.folder
                    onClicked: root.service?.toggle()
                }
                Ui.Button {
                    text: "Next"
                    foreground: root.bar.foreground
                    enabled: !!root.service?.folder
                    onClicked: root.service?.next()
                }
            }
        }
    }
}
