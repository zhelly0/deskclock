import QtQuick
import QtQuick.Effects

// Frosted-glass backdrop for desktop widgets.
//
// KWin's blur only blurs what's behind a window, and desktop widgets live in
// the same window as the wallpaper, so there is nothing behind them to blur.
// Instead this samples the wallpaper item directly: it grabs the patch of
// wallpaper under itself (plus a margin so the blur has data at the edges),
// blurs it, and clips it to a rounded rectangle.
Item {
    id: glass

    property real radius: 0
    property real blurAmount: 1.0      // 0..1
    property int blurMax: 48
    property real saturation: 0        // -1..1, 0 = unchanged
    property real brightness: 0        // -1..1, 0 = unchanged

    readonly property int pad: blurMax
    property Item wallpaper: null
    property rect region: Qt.rect(0, 0, 0, 0)

    function findWallpaper() {
        let top = glass;
        while (top.parent) top = top.parent;
        function walk(it, depth) {
            if (!it || depth > 8) return null;
            if (String(it).indexOf("WallpaperItem") === 0) return it;
            for (let i = 0; i < it.children.length; i++) {
                const hit = walk(it.children[i], depth + 1);
                if (hit) return hit;
            }
            return null;
        }
        return walk(top, 0);
    }

    function updateRegion() {
        if (!visible || width <= 0 || height <= 0) return;
        if (!wallpaper) wallpaper = findWallpaper();
        if (!wallpaper) return;
        const p = glass.mapToItem(wallpaper, 0, 0);
        const r = Qt.rect(Math.round(p.x) - pad, Math.round(p.y) - pad, Math.ceil(width) + 2 * pad, Math.ceil(height) + 2 * pad);
        if (r.x !== region.x || r.y !== region.y || r.width !== region.width || r.height !== region.height) region = r;
    }

    onWidthChanged: Qt.callLater(updateRegion)
    onHeightChanged: Qt.callLater(updateRegion)
    onVisibleChanged: Qt.callLater(updateRegion)
    Component.onCompleted: Qt.callLater(updateRegion)
    // Widgets can be moved (or repositioned automatically) without this item
    // resizing, so recheck the position now and then; it's a cheap comparison.
    Timer {
        interval: 1500
        repeat: true
        running: glass.visible
        onTriggered: glass.updateRegion()
    }

    ShaderEffectSource {
        id: wallpaperPatch
        sourceItem: glass.wallpaper
        sourceRect: glass.region
        width: glass.region.width
        height: glass.region.height
        visible: false
    }

    Item {
        id: blurred
        anchors.fill: parent
        visible: false
        layer.enabled: true
        MultiEffect {
            x: -glass.pad
            y: -glass.pad
            width: glass.region.width
            height: glass.region.height
            source: wallpaperPatch
            blurEnabled: true
            blur: glass.blurAmount
            blurMax: glass.blurMax
            saturation: glass.saturation
            brightness: glass.brightness
        }
    }

    Rectangle {
        id: roundMask
        anchors.fill: parent
        radius: glass.radius
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: parent
        source: blurred
        maskEnabled: true
        maskSource: roundMask
        visible: glass.wallpaper !== null && glass.region.width > 0
    }
}
