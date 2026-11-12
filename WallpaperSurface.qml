// Reveal geometry adapted from Omarchy (MIT); see LICENSE.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Commons

Item {
    id: root
    property string path: ""
    property real pixelRatio: 1
    property string fit: "normal"
    property real revealProgress: 1
    property int front: -1
    property int loading: -1
    property string requestedPath: ""
    property string requestedFit: "normal"
    property string displayedPath: ""
    readonly property var buffers: [first, second]
    signal loadFailed(string path)

    function request() {
        // Keep only the latest request while a revealAnimation is in flight.
        if (revealAnimation.running) return
        if (!path) {
            loading = -1
            front = -1
            displayedPath = ""
            first.source = ""
            second.source = ""
            return
        }
        var url = "file://" + path.split("/").map(encodeURIComponent).join("/")
        if (front >= 0 && buffers[front].source.toString() === url && buffers[front].fit === fit) {
            if (loading >= 0) buffers[loading].source = ""
            loading = -1
            return
        }
        loading = front === 0 ? 1 : 0
        requestedPath = path
        requestedFit = fit
        var image = buffers[loading]
        image.opacity = 0
        image.z = 1
        image.fit = fit
        image.source = url
        checkReady()
    }

    function checkReady() {
        if (loading < 0 || revealAnimation.running) return
        var image = buffers[loading]
        if (image.status === Image.Error) {
            var failed = requestedPath
            loading = -1
            image.source = ""
            loadFailed(failed)
        } else if (image.status === Image.Ready) {
            revealProgress = 0
            image.opacity = 1
            revealAnimation.start()
        }
    }

    onPathChanged: request()
    onFitChanged: request()
    Component.onCompleted: request()

    // Match Omarchy’s center-out slanted reveal. Keep the outgoing image
    // intact until decoding and the reveal have both finished.
    NumberAnimation {
        id: revealAnimation
        target: root
        property: "revealProgress"
        from: 0
        to: 1
        duration: Style.duration(840)
        easing.type: Easing.OutCubic
        onFinished: {
            var previous = root.front
            root.front = root.loading
            root.displayedPath = root.requestedPath
            root.loading = -1
            root.buffers[root.front].z = 0
            if (previous >= 0) {
                root.buffers[previous].opacity = 0
                root.buffers[previous].source = ""
            }
            if (root.path !== root.requestedPath || root.fit !== root.requestedFit) Qt.callLater(root.request)
        }
    }

    // Per-buffer fitting keeps the outgoing layout intact during a mode change.
    component Frame: Item {
        id: frame
        property alias source: image.source
        readonly property int status: image.status
        property int index: 0
        property string fit: "normal"
        anchors.fill: parent
        clip: true
        opacity: 0
        layer.enabled: root.loading === index && root.revealProgress < 1
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: revealMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.02
        }
        onStatusChanged: Qt.callLater(root.checkReady)
        Rectangle { anchors.fill: parent; color: "black" }
        Image {
            id: image
            readonly property real aspect: implicitHeight > 0 ? implicitWidth / implicitHeight : 1
            anchors.centerIn: parent
            width: frame.fit === "vertical" ? parent.height * aspect : parent.width
            height: frame.fit === "horizontal" ? parent.width / aspect : parent.height
            sourceSize: Qt.size(Math.ceil(root.width * root.pixelRatio), Math.ceil(root.height * root.pixelRatio))
            fillMode: frame.fit === "normal" ? Image.PreserveAspectCrop : Image.Stretch
            asynchronous: true
            cache: false
        }
    }
    Frame { id: first; index: 0 }
    Frame { id: second; index: 1 }

    Item {
        id: revealMask
        anchors.fill: parent
        visible: false
        layer.enabled: root.loading >= 0 && root.revealProgress < 1
        readonly property real slant: -0.18
        readonly property real centerTop: width / 2 - slant * height / 2
        readonly property real centerBottom: width / 2 + slant * height / 2
        readonly property real reach: width / 2 + Math.abs(slant) * height / 2 + 4
        readonly property real spread: reach * root.revealProgress
        Shape {
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "white"
                strokeColor: "transparent"
                startX: revealMask.centerTop - revealMask.spread; startY: 0
                PathLine { x: revealMask.centerTop + revealMask.spread; y: 0 }
                PathLine { x: revealMask.centerBottom + revealMask.spread; y: revealMask.height }
                PathLine { x: revealMask.centerBottom - revealMask.spread; y: revealMask.height }
                PathLine { x: revealMask.centerTop - revealMask.spread; y: 0 }
            }
        }
    }
}
