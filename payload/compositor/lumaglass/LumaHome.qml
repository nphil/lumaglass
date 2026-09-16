import QtQuick 2.4
import QtGraphicalEffects 1.0
import QtQuick.Window 2.2
import WebOSCompositorBase 1.0
import WebOS.Global 1.0
import "LumaBus.js" as Bus

// The compositor-drawn Home: wallpaper, glass material, status bar, widget grid and dock,
// driven by /var/lib/lumaglass/theme/{theme.json,layout.json}. Keys arrive through
// LumaBus.js from the configd-registered key filter (payload/keyfilter/lumaglass.js);
// pointer input arrives as ordinary QtQuick mouse events because this item sits above the
// Home surface.
Item {
    id: root
    anchors.fill: parent

    // set by StarfishFullscreenContainer: Home is this container's app and visible
    property bool hostActive: false

    readonly property string themeDirUrl: "file:///var/lib/lumaglass/theme/"
    readonly property string fontsDirUrl: "file:///var/lib/lumaglass/fonts/"
    readonly property string moduleDirUrl: "file:///var/lib/lumaglass/qml/WebOSCompositor/lumaglass/"

    property var theme: defaultTheme()
    property var layout: defaultLayout()
    property bool isLight: false
    property var mat: theme.dark
    property bool fpsEnabled: false
    property string lastThemeText: ""
    property string lastLayoutText: ""

    // ---- motion tokens ----
    function easingFromName(n) {
        if (!n) return Easing.OutCubic
        var v = Easing[n]
        return (v !== undefined) ? v : Easing.OutCubic
    }
    property var motion: theme.motion || {}
    property bool motionReduced: !!motion.reduced
    property int focusMs: motion.focusMs || 150
    property int focusEasing: easingFromName(motion.focusEasing)
    property int cardMs: motion.cardMs || 180
    property int cardEasing: easingFromName(motion.cardEasing)
    property int scrollMs: motion.scrollMs || 300
    property int scrollEasing: easingFromName(motion.scrollEasing)
    property int labelMs: motion.labelMs || 120
    property int layerMs: motion.layerMs || 220

    // ============================================================= defaults
    function defaultTheme() {
        return {
            version: 1, name: "LumaGlass default", wallpaper: "wall_1080.png",
            material: "auto", materialThreshold: 0.55,
            dark: { ink: "#F2EFF6", ink2: "#A8F2EFF6", ink3: "#6BF2EFF6", glass: "#66120E1A", glassEdge: "#21FFFFFF",
                    glassFocus: "#8F2C263A", glassFocusEdge: "#33FFFFFF", scrim: [0.10, 0.18, 0.46] },
            light: { ink: "#17131F", ink2: "#A817131F", ink3: "#6B17131F", glass: "#85FFFFFF", glassEdge: "#D9FFFFFF",
                     glassFocus: "#B8FFFFFF", glassFocusEdge: "#E6FFFFFF", scrim: [0.06, 0.10, -0.10] },
            accent: "tile", radius: 26, tileRadius: 22, blurRadius: 30, saturation: 0.25,
            type: { clock: 92, temp: 84 },
            focus: { tileScale: 1.12, cardScale: 1.03, cardLift: 4 },
            motion: { focusMs: 150, focusEasing: "OutCubic", cardMs: 180, cardEasing: "OutCubic",
                      scrollMs: 300, scrollEasing: "OutCubic", labelMs: 120, layerMs: 220, reduced: false },
            tiles: { inset: 19, fullCanvasEdgeAlpha: 0.9, icons: {} },
            clock: { style: "digital", twelveHour: true, greeting: true, secondHand: "#ff3b5c" },
            weather: { zip: "30311", units: "fahrenheit", days: 5 },
            news: { slideMs: 10000, refreshMs: 900000 }
        }
    }
    function defaultLayout() {
        return {
            version: 1, safe: { x: 64, y: 54 }, grid: { cols: 12, gutter: 20, rows: [222, 238, 392] },
            statusBar: { height: 60, gap: 20,
                left: [ { type: "profile" } ],
                right: [ { type: "notifications" }, { type: "settings" }, { type: "search" } ] },
            widgets: [
                { id: "clock", type: "clock", col: 0, row: 0, span: 4, rows: 1 },
                { id: "home", type: "homeassistant", col: 0, row: 1, span: 4, rows: 1, title: "At home" },
                { id: "news", type: "news", col: 4, row: 0, span: 5, rows: 2 },
                { id: "weather", type: "weather", col: 9, row: 0, span: 3, rows: 2 },
                { id: "dock", type: "dock", col: 0, row: 2, span: 12, rows: 1, tile: 120, gap: 16, padY: 40, fade: 110 }
            ]
        }
    }

    function resolvePath(p) {
        if (!p) return ""
        if (/^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(p)) return p
        if (p.charAt(0) === "/") return "file://" + p
        return themeDirUrl + p
    }

    // ============================================================= grid geometry
    // grid.rows is either a count (uniform rows filling the area) or an array of pixel
    // heights (the reference layout pins the mock's 222/238/392).
    function areaRect() {
        var x = layout.safe.x, y = layout.safe.y + layout.statusBar.height + layout.statusBar.gap
        return Qt.rect(x, y, 1920 - 2 * layout.safe.x, 1080 - 2 * layout.safe.y - layout.statusBar.height - layout.statusBar.gap)
    }
    function rowHeights() {
        var a = areaRect(), g = layout.grid
        if (g.rows && g.rows.length !== undefined) return g.rows
        var n = Math.max(1, g.rows || 8), h = (a.height - (n - 1) * g.gutter) / n, out = []
        for (var i = 0; i < n; i++) out.push(h)
        return out
    }
    function rowCount() { return rowHeights().length }
    function cellRect(entry) {
        var a = areaRect(), g = layout.grid, rows = rowHeights()
        var cellW = (a.width - (g.cols - 1) * g.gutter) / g.cols
        var y = a.y, h = 0
        for (var r = 0; r < entry.row && r < rows.length; r++) y += rows[r] + g.gutter
        for (var k = entry.row; k < entry.row + entry.rows && k < rows.length; k++) h += rows[k] + (k > entry.row ? g.gutter : 0)
        return Qt.rect(Math.round(a.x + entry.col * (cellW + g.gutter)), Math.round(y),
                       Math.round(entry.span * cellW + (entry.span - 1) * g.gutter), Math.round(h))
    }
    property var nonDockWidgets: (layout.widgets || []).filter(function(e) { return e.type !== "dock" })
    property var dockEntry: { var l = (layout.widgets || []).filter(function(e) { return e.type === "dock" }); return l.length ? l[0] : null }
    function widgetIndexById(id) {
        for (var i = 0; i < nonDockWidgets.length; i++) if (nonDockWidgets[i].id === id) return i
        return -1
    }
    function isTopRow(e) { return e.row === 0 }
    function isBottomRow(e) { return dockEntry ? (e.row + e.rows) === dockEntry.row : (e.row + e.rows) === rowCount() }

    // ============================================================= JSON load / reload
    function loadJson(url, cb) {
        var x = new XMLHttpRequest()
        x.onreadystatechange = function() {
            if (x.readyState !== 4) return
            if (x.responseText && (x.status === 200 || x.status === 0)) {
                try { cb(JSON.parse(x.responseText), x.responseText); return }
                catch (e) { console.warn("[LumaHome] invalid JSON at " + url + ": " + e) }
            }
            cb(null, null)
        }
        try { x.open("GET", url); x.send() } catch (e) { cb(null, null) }
    }
    function mergeDefaults(base, over) {
        if (!over || typeof over !== "object") return base
        var out = {}
        for (var k in base) out[k] = base[k]
        for (var k2 in over) out[k2] = over[k2]
        return out
    }
    function applyTheme(json, text) {
        root.theme = json ? mergeDefaults(defaultTheme(), json) : defaultTheme()
        if (!json) console.warn("[LumaHome] theme.json missing/invalid, using built-in defaults")
        root.lastThemeText = text || ""
        computeMaterial()
    }
    function applyLayout(json, text) {
        root.layout = json ? mergeDefaults(defaultLayout(), json) : defaultLayout()
        if (!json) console.warn("[LumaHome] layout.json missing/invalid, using built-in defaults")
        root.lastLayoutText = text || ""
        if (widgetIndexById(widgetFocusId) < 0) widgetFocusId = nonDockWidgets.length ? nonDockWidgets[0].id : ""
    }
    function loadFpsSetting() {
        loadJson(moduleDirUrl + "settings.json", function(json) { root.fpsEnabled = !!(json && json.fps) })
    }
    function loadAll() {
        loadJson(themeDirUrl + "theme.json", applyTheme)
        loadJson(themeDirUrl + "layout.json", applyLayout)
        loadFpsSetting()
    }
    function reload() { loadAll() }
    Timer {
        // live theme preview for the companion app: content compare every 2 s, no restart
        interval: 2000; running: true; repeat: true
        onTriggered: {
            loadJson(root.themeDirUrl + "theme.json", function(json, text) { if ((text || "") !== root.lastThemeText) root.applyTheme(json, text) })
            loadJson(root.themeDirUrl + "layout.json", function(json, text) { if ((text || "") !== root.lastLayoutText) root.applyLayout(json, text) })
        }
    }

    // ============================================================= fonts
    FontLoader { source: root.fontsDirUrl + "Manrope-Medium.ttf" }
    FontLoader { source: root.fontsDirUrl + "Manrope-SemiBold.ttf" }
    FontLoader { source: root.fontsDirUrl + "Manrope-Bold.ttf" }
    Repeater { model: theme.fonts || []; delegate: FontLoader { source: root.resolvePath(modelData) } }

    // ============================================================= material (light/dark)
    function computeMaterial() {
        if (theme.material === "light") { root.isLight = true; root.mat = theme.light; return }
        if (theme.material === "dark") { root.isLight = false; root.mat = theme.dark; return }
        if (wallpaperImg.status === Image.Ready) lumaSampler.requestPaint()
    }
    Canvas {
        // "auto": mean luminance of the wallpaper against theme.materialThreshold
        id: lumaSampler
        width: 16; height: 9; visible: false
        onPaint: {
            var ctx = getContext("2d")
            ctx.drawImage(wallpaperImg, 0, 0, 16, 9)
            var d = ctx.getImageData(0, 0, 16, 9).data, sum = 0
            for (var i = 0; i < d.length; i += 4) sum += 0.299 * d[i] + 0.587 * d[i + 1] + 0.114 * d[i + 2]
            root.isLight = (sum / (16 * 9) / 255) > root.theme.materialThreshold
            root.mat = root.isLight ? root.theme.light : root.theme.dark
        }
    }
    function scrimColor(v) {
        if (!root.isLight) return Qt.rgba(0, 0, 0, v)
        return v >= 0 ? Qt.rgba(1, 1, 1, v) : Qt.rgba(0, 0, 0, -v)
    }

    // ============================================================= wallpaper + one cached blur
    property string wallpaperFit: (layout.background && layout.background.wallpaperFit) || "1:1"
    Rectangle { anchors.fill: parent; z: -3; color: (layout.background && layout.background.color) || "#0b0910" }
    Image {
        id: wallpaperImg
        anchors.fill: parent
        z: -2
        source: root.resolvePath(theme.wallpaper)
        asynchronous: true
        cache: false
        fillMode: root.wallpaperFit === "cover" ? Image.PreserveAspectCrop
                  : root.wallpaperFit === "contain" ? Image.PreserveAspectFit : Image.Stretch
        onStatusChanged: if (status === Image.Ready) root.computeMaterial()
    }
    Rectangle {
        // theme.<mat>.scrim: 3 stops at 0 / 55 / 100 %
        anchors.fill: parent
        z: -1
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.scrimColor((root.mat.scrim || [0, 0, 0])[0]) }
            GradientStop { position: 0.55; color: root.scrimColor((root.mat.scrim || [0, 0, 0])[1]) }
            GradientStop { position: 1.0; color: root.scrimColor((root.mat.scrim || [0, 0, 0])[2]) }
        }
    }
    // The glass backdrop: wallpaper at half resolution, blurred and saturated once (the
    // sources are static, so the live chain re-renders only when the wallpaper changes).
    // Every Glass samples blurTex at its own screen rect; nothing here runs per frame.
    ShaderEffectSource {
        id: wallHalf
        sourceItem: wallpaperImg
        width: 960; height: 540
        textureSize: Qt.size(960, 540)
        visible: false
    }
    GaussianBlur {
        id: blurPass
        width: 960; height: 540
        source: wallHalf
        radius: Math.round((root.theme.blurRadius || 30) / 2)
        samples: radius * 2 + 1
        visible: false
    }
    HueSaturation {
        id: satPass
        width: 960; height: 540
        source: blurPass
        saturation: root.theme.saturation === undefined ? 0.25 : root.theme.saturation
        visible: false
    }
    ShaderEffectSource {
        id: blurTex
        sourceItem: satPass
        width: 960; height: 540
        textureSize: Qt.size(960, 540)
        visible: false
        smooth: true
    }

    // ============================================================= focus model
    // "dock" | "widgets" | "statusbar" | "popover"
    property string focusLayer: "dock"
    property int dockRow: 0
    property int dockCol: 0
    property string widgetFocusId: nonDockWidgets.length ? nonDockWidgets[0].id : ""
    property int statusFocusIndex: 0
    property var statusItems: (layout.statusBar.left || []).concat(layout.statusBar.right || [])
    property bool popoverOpen: focusLayer === "popover"

    onHostActiveChanged: if (hostActive) { focusLayer = "dock"; statusBarItem.popoverOpen = false }

    function widgetRectById(id) {
        var i = widgetIndexById(id)
        return i >= 0 ? cellRect(nonDockWidgets[i]) : null
    }
    function nearestWidgetByX(x) {
        var best = -1, bestD = Infinity
        for (var i = 0; i < nonDockWidgets.length; i++) {
            var r = cellRect(nonDockWidgets[i])
            var d = Math.abs((r.x + r.width / 2) - x)
            if (d < bestD) { bestD = d; best = i }
        }
        return best >= 0 ? nonDockWidgets[best].id : ""
    }
    function lowestWidgetByX(x) {
        // entering from the dock: prefer the card whose bottom edge is nearest the dock
        var best = -1, bestScore = Infinity
        for (var i = 0; i < nonDockWidgets.length; i++) {
            var r = cellRect(nonDockWidgets[i])
            var score = Math.abs((r.x + r.width / 2) - x) + (areaRect().y + areaRect().height - (r.y + r.height)) * 2
            if (score < bestScore) { bestScore = score; best = i }
        }
        return best >= 0 ? nonDockWidgets[best].id : ""
    }
    function nearestWidgetInDirection(fromId, dx, dy) {
        var fr = widgetRectById(fromId)
        if (!fr) return fromId
        var fcx = fr.x + fr.width / 2, fcy = fr.y + fr.height / 2
        var best = -1, bestScore = Infinity
        for (var i = 0; i < nonDockWidgets.length; i++) {
            var e = nonDockWidgets[i]
            if (e.id === fromId) continue
            var r = cellRect(e)
            var cx = r.x + r.width / 2, cy = r.y + r.height / 2
            var ddx = cx - fcx, ddy = cy - fcy
            if (dx !== 0 && ddx * dx <= 0) continue
            if (dy !== 0 && ddy * dy <= 0) continue
            var primary = dx !== 0 ? Math.abs(ddx) : Math.abs(ddy)
            var secondary = dx !== 0 ? Math.abs(ddy) : Math.abs(ddx)
            var score = primary + secondary * 2
            if (score < bestScore) { bestScore = score; best = i }
        }
        return best >= 0 ? nonDockWidgets[best].id : fromId
    }

    function directionFor(k) {
        if (k === Qt.Key_Left) return "left"
        if (k === Qt.Key_Right) return "right"
        if (k === Qt.Key_Up) return "up"
        if (k === Qt.Key_Down) return "down"
        if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select) return "ok"
        if (k === Qt.Key_Back || k === WebOS.Key_webOS_Back) return "back"
        return ""
    }

    // Returns true when the key is consumed; false lets the stock chain deliver it to Home's
    // own surface (Back from the widget layer closes Home exactly as stock does).
    function key(k, pressed, autoRepeat, deviceId) {
        var dir = directionFor(k)
        if (!dir || !hostActive) return false
        if (!pressed) return true
        var d = dockLoader.item

        if (focusLayer === "popover") {
            if (dir === "back" || dir === "ok") { statusBarItem.popoverOpen = false; focusLayer = "statusbar" }
            return true
        }
        if (focusLayer === "dock") {
            if (!d) return false
            if (dir === "left") d.moveLeft()
            else if (dir === "right") d.moveRight()
            else if (dir === "down") d.moveDown()
            else if (dir === "up") { if (!d.moveUp()) { widgetFocusId = lowestWidgetByX(d.focusedCenterX()); focusLayer = "widgets" } }
            else if (dir === "back") { widgetFocusId = lowestWidgetByX(d.focusedCenterX()); focusLayer = "widgets" }
            else if (dir === "ok") d.activate()
            return true
        }
        if (focusLayer === "widgets") {
            if (dir === "back") return false
            var idx = widgetIndexById(widgetFocusId)
            var entry = idx >= 0 ? nonDockWidgets[idx] : null
            if (dir === "ok") { var wi = idx >= 0 ? widgetRepeater.itemAt(idx) : null; if (wi) wi.activate(); return true }
            if (dir === "up" && entry && isTopRow(entry)) { statusFocusIndex = nearestStatusByX(cellRect(entry).x + cellRect(entry).width / 2); focusLayer = "statusbar"; return true }
            if (dir === "down" && entry && isBottomRow(entry) && d) {
                var r = cellRect(entry)
                d.col = Math.max(0, Math.min(d.cols - 1, Math.round((r.x + r.width / 2 - d.originX - d.padX - d.tileSize / 2) / (d.tileSize + d.gap))))
                d.row = d.scrollRow
                if (d.row * d.cols + d.col >= d.points.length) d.col = Math.max(0, d.points.length - 1 - d.row * d.cols)
                focusLayer = "dock"
                return true
            }
            var dx = dir === "left" ? -1 : dir === "right" ? 1 : 0
            var dy = dir === "up" ? -1 : dir === "down" ? 1 : 0
            if (dx !== 0 || dy !== 0) widgetFocusId = nearestWidgetInDirection(widgetFocusId, dx, dy)
            return true
        }
        if (focusLayer === "statusbar") {
            if (dir === "back") return false
            if (dir === "left") statusFocusIndex = Math.max(0, statusFocusIndex - 1)
            else if (dir === "right") statusFocusIndex = Math.min(statusItems.length - 1, statusFocusIndex + 1)
            else if (dir === "down") { widgetFocusId = nearestWidgetByX(statusBarItem.focusedGlobalX()); focusLayer = "widgets" }
            else if (dir === "ok") statusBarItem.activate(statusFocusIndex)
            return true
        }
        return false
    }
    function nearestStatusByX(x) {
        var best = 0, bestD = Infinity
        for (var i = 0; i < statusItems.length; i++) {
            var it = statusBarItem.itemAt(i)
            if (!it) continue
            var cx = statusBarItem.x + it.parent.x + it.x + 24
            if (Math.abs(cx - x) < bestD) { bestD = Math.abs(cx - x); best = i }
        }
        return best
    }
    Component.onCompleted: { Bus.setHandler(root.key); loadAll() }
    Component.onDestruction: Bus.setHandler(null)

    // Pointer: anything not over a card/tile lands here so the stock Home underneath never
    // sees the Magic Remote.
    MouseArea { anchors.fill: parent; hoverEnabled: true; z: 0 }

    // ============================================================= chrome
    StatusBar {
        id: statusBarItem
        z: 3
        x: layout.safe.x
        y: layout.safe.y
        width: 1920 - 2 * layout.safe.x
        height: layout.statusBar.height
        theme: root.theme
        mat: root.mat
        isLight: root.isLight
        items: root.statusItems
        leftCount: (layout.statusBar.left || []).length
        focusedLayer: root.focusLayer === "statusbar" || root.focusLayer === "popover"
        focusedIndex: root.statusFocusIndex
        backdrop: blurTex
        cardMs: root.cardMs
        cardEasing: root.cardEasing
        layerMs: root.layerMs
        onRequestOpenPopover: { root.statusFocusIndex = index; root.focusLayer = "popover" }
        onHoverFocus: { root.statusFocusIndex = index; if (root.focusLayer !== "popover") root.focusLayer = "statusbar" }
    }

    Item {
        id: widgetLayer
        anchors.fill: parent
        z: 1
        Repeater {
            id: widgetRepeater
            model: root.nonDockWidgets
            delegate: Widget {
                gridX: root.cellRect(modelData).x
                gridY: root.cellRect(modelData).y
                width: root.cellRect(modelData).width
                height: root.cellRect(modelData).height
                theme: root.theme
                mat: root.mat
                isLight: root.isLight
                layoutEntry: modelData
                themeDirUrl: root.themeDirUrl
                moduleDirUrl: root.moduleDirUrl
                focused: root.focusLayer === "widgets" && root.widgetFocusId === modelData.id
                dimmed: (root.focusLayer === "widgets" && root.widgetFocusId !== modelData.id) || root.popoverOpen
                backdrop: blurTex
                cardMs: root.cardMs
                cardEasing: root.cardEasing
                motionReduced: root.motionReduced
                onHoverFocus: { root.widgetFocusId = modelData.id; root.focusLayer = "widgets" }
            }
        }
    }

    Loader {
        id: dockLoader
        z: 1
        active: root.dockEntry !== null
        x: active ? root.cellRect(root.dockEntry).x : 0
        y: active ? root.cellRect(root.dockEntry).y : 0
        width: active ? root.cellRect(root.dockEntry).width : 0
        height: active ? root.cellRect(root.dockEntry).height : 0
        sourceComponent: Dock {
            theme: root.theme
            mat: root.mat
            isLight: root.isLight
            dockEntry: root.dockEntry || ({})
            originX: dockLoader.x
            originY: dockLoader.y
            focusedLayer: root.focusLayer === "dock"
            dimmed: root.focusLayer === "widgets" || root.popoverOpen
            backdrop: blurTex
            scrollMs: root.scrollMs
            scrollEasing: root.scrollEasing
            focusMs: root.focusMs
            focusEasing: root.focusEasing
            labelMs: root.labelMs
            motionReduced: root.motionReduced
            onRowChanged: root.dockRow = row
            onColChanged: root.dockCol = col
        }
        MouseArea {
            // hovering the dock card itself hands the layer to the dock
            anchors.fill: parent
            hoverEnabled: true
            z: -1
            onEntered: root.focusLayer = "dock"
        }
    }

    // ============================================================= fps overlay / log
    QtObject { id: fpsProbe; property int frames: 0; property int fps: 0 }
    Connections { target: root.Window.window; onFrameSwapped: fpsProbe.frames++ }
    Timer {
        interval: 1000; running: root.fpsEnabled; repeat: true
        onTriggered: { fpsProbe.fps = fpsProbe.frames; fpsProbe.frames = 0; console.info("[FPSLOG] luma " + fpsProbe.fps) }
    }
    Rectangle {
        visible: root.fpsEnabled
        x: parent.width - width - 24; y: 24; z: 100
        width: fpsText.implicitWidth + 28; height: 34; radius: 8; color: "#a0100e1a"
        Text {
            id: fpsText
            x: 14; y: Math.round((34 - implicitHeight) / 2)
            color: "#9ccfd8"
            font.family: "Manrope"; renderType: Text.NativeRendering; font.pixelSize: 18
            text: "luma " + fpsProbe.fps + " fps"
        }
    }
}
