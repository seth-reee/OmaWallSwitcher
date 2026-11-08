import QtQuick
import QtTest
import qs.Commons
import "TextSafety.js" as TextSafety
TestCase {
    name: "WallpaperSurface"
    width: 128; height: 128
    when: windowShown
    WallpaperSurface { id: surface; anchors.fill: parent }
    function imagePath(name) {
        return decodeURIComponent(Qt.resolvedUrl(name).toString().replace(/^file:\/\//, ""))
    }
    function test_tooltip_markup() {
        compare(TextSafety.tooltip('<img src="https://example.invalid/a">'),
                '‹img src="https://example.invalid/a"›')
        compare(TextSafety.tooltip('Pictures/A & B'), 'Pictures/A & B')
        compare(TextSafety.tooltip(null), '')
    }
    function test_animations_disabled() {
        Style.animated = false
        surface.path = imagePath("red.ppm")
        tryVerify(() => surface.front >= 0)
        surface.fit = "vertical"
        tryVerify(() => surface.loading === -1 && surface.buffers[surface.front].fit === "vertical")
        surface.path = ""
        surface.fit = "normal"
        Style.animated = true
    }
    function test_fitting() {
        surface.path = imagePath("wide.ppm")
        tryVerify(() => surface.front >= 0)
        for (var mode of ["vertical", "horizontal", "stretch", "normal"]) {
            var old = surface.front
            var oldMode = surface.buffers[old].fit
            surface.fit = mode
            compare(surface.buffers[old].fit, oldMode)
            compare(surface.buffers[old].opacity, 1)
            tryVerify(() => surface.front !== old)
            var frame = surface.buffers[surface.front]
            compare(frame.fit, mode)
            var image = frame.children[1]
            if (mode === "vertical") {
                compare(image.height, surface.height)
                compare(image.width, surface.height * 2)
            } else if (mode === "horizontal") {
                compare(image.width, surface.width)
                compare(image.height, surface.width / 2)
            } else {
                compare(image.width, surface.width)
                compare(image.height, surface.height)
            }
            compare(surface.buffers[old].source.toString(), "")
        }
        surface.fit = "vertical"
        wait(100)
        surface.fit = "stretch"
        surface.fit = "horizontal"
        tryVerify(() => surface.loading === -1 && surface.buffers[surface.front].fit === "horizontal")
        surface.path = ""
        surface.fit = "normal"
    }
    function test_transitions() {
        surface.path = imagePath("red.ppm")
        tryVerify(() => surface.front >= 0)
        var previous = surface.front
        compare(surface.buffers[previous].opacity, 1)
        surface.path = imagePath("blue.ppm")
        compare(surface.buffers[previous].source.toString(), Qt.resolvedUrl("red.ppm").toString())
        compare(surface.buffers[previous].opacity, 1)
        tryVerify(() => surface.front !== previous)
        compare(surface.buffers[previous].source.toString(), "")
        ignoreWarning(/.*Cannot open:.*missing.png/)
        surface.path = imagePath("missing.png")
        tryCompare(surface, "loading", -1)
        compare(surface.front, 1 - previous)
        compare(surface.buffers[surface.front].opacity, 1)
        surface.path = imagePath("red.ppm")
        tryVerify(() => surface.front === previous)
        surface.path = imagePath("blue.ppm")
        surface.path = imagePath("red.ppm")
        wait(600)
        compare(surface.buffers[surface.front].source.toString(), Qt.resolvedUrl("red.ppm").toString())
        compare(surface.loading, -1)
        surface.path = ""
        compare(surface.front, -1)
        compare(surface.buffers[0].source.toString(), "")
        compare(surface.buffers[1].source.toString(), "")
    }
}
