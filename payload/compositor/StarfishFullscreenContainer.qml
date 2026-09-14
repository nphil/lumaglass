/* @@@LICENSE
 *
 * Copyright (c) 2021-2025 LG Electronics, Inc.
 *
 * Confidential computer software. Valid license from LG required for
 * possession, use or copying. Consistent with FAR 12.211 and 12.212,
 * Commercial Computer Software, Computer Software Documentation, and
 * Technical Data for Commercial Items are licensed to the U.S. Government
 * under vendor's standard commercial license.
 *
 * LICENSE@@@ */

import QtQuick 2.4
import QtGraphicalEffects 1.0
import QtQuick.Window 2.2
import WebOSCompositorBase 1.0
import WebOSCoreCompositor 1.0
import WebOSCompositor 1.0
import WebOS.Global 1.0

import "../../services/base"

FocusScope {
    id: root
    z:-1

    signal focused()
    signal unfocused()

    property var windowPosition: (root && root.__surfaceItem && root.__surfaceItem.windowProperties.windowPosition) ? JSON.parse(root.__surfaceItem.windowProperties.windowPosition) : []
    property var containerInfo : getContainerInfo()
    property bool active: root.__surfaceItem ? root.__surfaceItem.activeFocus : false
    property Item __surfaceItem: null
    property var __displayWindowNotified: []
    property var controlMode: false
    property int cursorFps: (root && root.__surfaceItem && root.__surfaceItem.windowProperties.cursor_fps) ? Number(root.__surfaceItem.windowProperties.cursor_fps) : 0
    property bool cursorDisplay: (root && root.__surfaceItem && root.__surfaceItem.windowProperties.cursor_display) ? (root.__surfaceItem.windowProperties.cursor_display === "true" ? true : false) : false
    property bool cloudgameActivefromWinProp: (root && root.__surfaceItem && root.__surfaceItem.windowProperties.cloudgame_active) ? (root.__surfaceItem.windowProperties.cloudgame_active === "true" ? true : false) : false
    property bool cloudgameActivefromAppInfo: root && root.__surfaceItem && LS.applicationManager.appInfoList[root.__surfaceItem.appId] && LS.applicationManager.appInfoList[root.__surfaceItem.appId].cloudgame_active ? LS.applicationManager.appInfoList[root.__surfaceItem.appId].cloudgame_active : false
    property string __restoreCursorPositionSetting: (root && root.__surfaceItem && root.__surfaceItem.windowProperties.restore_cursor_position) ? root.__surfaceItem.windowProperties.restore_cursor_position : "false"
    property alias decoration: ssd
    property var __surfaceItemType: (root && root.__surfaceItem) ? root.__surfaceItem.type : null
    property var __surfaceItemScale: 1
    property bool __beforeAnimation: true
    property bool __showToolbarStatus: false
    property var multiviewControllerService: null
    property bool needItemFocus: false
    property bool isGeometryChanged: false
    property bool visibleState: (root.width > 0) && (root.height > 0)
    property string currentMode: ""
    property int currentOrder: -1  // default value?
    property var coverState: SurfaceItem.CoverStateNormal
    property bool fitOnParent: (root.width === root.parent.width) && (root.height === root.parent.height)
    property bool hasFocusedSurfaceItem: root.active || hasActiveGroupedItem()
    property bool standbyVisible: fullscreenStandby.visible
    property bool emptySurfaceItem : (isMultiViewMode() == true) && emptyCurrentItem()
    property bool forceAnimation: false
    property bool directDestroy: false
    property bool connected: false

    property string controllerModeGuideStr: qsTr("Please press and hold the back button on the remote control to return to the previous screen.") + Settings.l10n.tr
    property var languageStyle: StarfishUtils.languageStyle
    property bool surfaceItemContainsMouse: root.__surfaceItem && root.__surfaceItem.containsMouse && decoration.inputMode && ssd.__config.buttons
    property bool dragCover: ssd.dragging
    property string animationState: "ready"

    property bool grouped: false
    property var __groupedItems: []
    property var __groupLowerChildren: []
    property var __groupUpperChildren: []

    property QtObject __layoutInfo: QtObject {
        property string appId: ""
        property string mode: ""
        property string usageType: ""
        property int order: -1
        property int x: 0
        property int y: 0
        property int z: 0
        property int width: 0
        property int height: 0
        property bool visibleState: false
        property string multiviewOrientation: "landscape"
        property int rotation: 0
        property bool isPipSub: false
        property var decorationConfig: ({})
        function reset()
        {
            console.info("[FULLSCREEN:Container][" + root.objectName + "] reset layoutInfo")
            appId = ""; mode = ""; usageType = ""; order = -1;
            x = 0; y = 0; z = 0; width = 0; height = 0;
            visibleState = false; multiviewOrientation = "landscape"; rotation = 0;
            isPipSub = false; decorationConfig = ({});
        }
    }

    property QtObject __pendingLayoutInfo: QtObject {
        property bool isPending: false
        property bool needReset: false
        property bool changedExceptGeometry: true
        property int x: 0
        property int y: 0
        property int z: 0
        property int width: 0
        property int height: 0
        property string multiviewOrientation: "landscape"
        property bool isPipSub: false
        property var decorationConfig: ({})
        function reset() {
            isPending = false; needReset = false; changedExceptGeometry = true;
            x = 0; y = 0; z = 0; width = 0; height = 0;
            multiviewOrientation = "landscape";
            isPipSub = false; decorationConfig = ({});
        }
    }

    signal groupUpdated(var groupLowerChildren, var groupUpperChildren, var change)
    signal layoutInfoUpdated()
    signal appStateChanged()
    signal surfaceItemChanged()
    signal groupedStatusUpdated()
    signal focusedSurfaceItem(int order, bool focus)
    signal focusedDecoration(int order, string direction)
    signal requestShowToolbar(int order, bool delayed, string mode)
    signal applyLayoutDone(var obj)

    Component.onCompleted: {
        console.info("[FULLSCREEN:Container][MVN] " + root.objectName  + " completed")
    }

    Component.onDestruction: {
        console.info("[FULLSCREEN:Container][MVN] " + root.objectName  + " destruction")
    }

    property Item __livedmostItem: null

    property StarfishForegroundVideoWindowMgr foregroundVideoWindowMgr: StarfishForegroundVideoWindowMgr {
        onForegroundVideoWindowChanged: {
            if (root.__layoutInfo.isPipSub === true) {
                // bgBlack unvisible only when layout is not pip or sub
                return
            }
            if (bgBlack.visible == false) {
                return
            }

            var videoList = getForegroundVideoWindow()
            Utils.pmLog.info("SVU_LSM_BG_BLACK", {}, "[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] check bgBlack. video list : " + JSON.stringify(videoList) + ", grouped : " + root.grouped + ", groupedItems : " + root.__groupedItems);

            for (var i = 0; i < videoList.length; i++) {
                if (videoList[i] !== null && videoList[i] !== undefined) {
                    if (root.grouped && 0 < root.__groupedItems.length) {
                        for (var j = 0; j < root.__groupedItems.length; j++) {
                            if (videoList[i].appId === root.__groupedItems[j].appId) {
                                Utils.pmLog.info("SVU_LSM_BG_BLACK", {}, "[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] set bgBlack false by video is inserted to group." + JSON.stringify(videoList[i]));
                                __livedmostItem = root.__groupedItems[j]
                                bgBlack.visible = false
                                break
                            }
                        }
                    }
                    else if (root.__layoutInfo.appId === videoList[i].appId) {
                        Utils.pmLog.info("SVU_LSM_BG_BLACK", {}, "[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] set bgBlack false by video is inserted. " + JSON.stringify(videoList[i]) + root.__layoutInfo.appId);
                        bgBlack.visible = false
                        break
                    }
                }
            }
        }
    }

    Rectangle {
        id: bgBlack
        anchors.fill: parent
        color: "black"
        visible: false
        z: -999
        onVisibleChanged: {
            console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] bgBlack changed : " + visible);
        }
    }

    StarfishFullscreenStandby {
        id : fullscreenStandby
        anchors.fill: parent
        border.color : (root.__layoutInfo.mode === "pip" && !root.__layoutInfo.isPipSub) ? "transparent" : Settings.local.standbyIcon.borderColor
        visible : isMultiViewMode() && emptyCurrentItem() && ssd.__config.standbyIcon

        onVisibleChanged : console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "]  isMultiViewMode = " + isMultiViewMode() + " , emptyCurrentItem = " + emptyCurrentItem() + " Standby icon visible is changed = " + visible)
    }

    Item {
        id: surfaceItemContainer
        anchors.fill: parent
        clip: true
    }

    // --- custom: Rose Pine wallpaper keyed into the Home card's black background ---
    // Home paints an opaque black scaffold. This replaces pure-black pixels (max channel <= ~3/255)
    // with a wallpaper sampled at the same position, leaving icons/text/banner untouched.
    property bool homeKeyOn: (root.__surfaceItem && root.__surfaceItem.appId === "com.webos.app.home") ? true : false
    Image {
        id: homeWallImg
        source: "file:///tmp/hx/wall_1080.png"
        anchors.fill: parent
        visible: false
        smooth: true
    }
    GaussianBlur { id: homeWallBlur; anchors.fill: parent; source: homeWallImg; radius: 40; samples: 81; deviation: 14; visible: false }
    ShaderEffectSource { id: homeWallBlurSrc; sourceItem: homeWallBlur; anchors.fill: parent; visible: false; live: false }
    ShaderEffectSource {
        id: homeWallSrc
        sourceItem: homeWallImg
        anchors.fill: parent
        visible: false
        live: false
    }
    ShaderEffectSource {
        id: homeSurfSrc
        sourceItem: surfaceItemContainer
        anchors.fill: parent
        visible: false
        live: true
        hideSource: root.homeKeyOn
    }
    // =================== custom widget layer (glass cards) ===================
    Item {
        id: homeWidgets
        anchors.fill: parent
        z: 2
        visible: root.homeKeyOn
        property bool  twelveHour: true
        property string zip: "30311"
        property string units: "fahrenheit"
        // ---- 12-column layout grid (px, 1080p plane). Cards snap to columns; app rearranges via col/span ----
        property int  gridCols: 12
        property real gridMargin: 48
        property real gridGutter: 24
        property real gridTop: 44
        property real colW: (width - 2 * gridMargin - (gridCols - 1) * gridGutter) / gridCols
        function gx(col)  { return gridMargin + col * (colW + gridGutter) }
        function gw(span) { return span * colW + (span - 1) * gridGutter }
        property real rowH: 152
        function gh(rows) { return rows * rowH + (rows - 1) * gridGutter }
        // card placement: col/span (width) + rows (height). Content adapts to the resulting size class.
        property string clockStyle: "analog"          // "digital" | "analog"
        property int clockCol: 4;  property int clockSpan: 4;  property int clockRows: (clockStyle === "analog") ? 2 : 1
        property int wxCol: 9;     property int wxSpan: 3;     property int wxRows: 4
        property string wxIcons: "/usr/palm/applications/com.webos.app.home/data/flutter_assets/packages/elutter/lib/widgets/weather/assets/"
        // ---- news card: bottom-left, bottom-anchored above the dock (not on the grid's top rows) ----
        property int  newsCol: 0;  property int newsSpan: 6;  property int newsRows: 2
        property real newsDockGap: 28
        property int  newsSlideMs: 10000
        property int  newsRefreshMs: 900000
        property int  newsPerFeed: 4
        // Keyless public RSS: no account, no quota, and no API key to leak in a published widget.
        property var newsFeeds: [{ tag: "WORLD", src: "BBC News", url: "https://feeds.bbci.co.uk/news/world/rss.xml" },
                                 { tag: "U.S.",  src: "BBC News", url: "https://feeds.bbci.co.uk/news/world/us_and_canada/rss.xml" }]
        // Used only when the primary feeds return nothing; NYT carries longer summaries but larger images.
        property var newsFeedsAlt: [{ tag: "WORLD", src: "The New York Times", url: "https://rss.nytimes.com/services/xml/rss/nyt/World.xml" },
                                    { tag: "U.S.",  src: "The New York Times", url: "https://rss.nytimes.com/services/xml/rss/nyt/US.xml" }]
        property var newsItems: []
        property int newsIndex: 0

        function pad(n) { return (n < 10 ? "0" : "") + n }
        function fmtTime(d) {
            var h = d.getHours(), m = pad(d.getMinutes())
            if (!twelveHour) return pad(h) + ":" + m
            var hh = h % 12; if (hh === 0) hh = 12
            return hh + ":" + m
        }
        function greet(d) { var h = d.getHours(); return h < 5 ? "Good night." : h < 12 ? "Good morning." : h < 17 ? "Good afternoon." : h < 22 ? "Good evening." : "Good night." }
        function wxIcon(code, isDay) {
            var p = wxIcons
            if (code === 0) return p + (isDay ? "04_weather_fair_day_l.png" : "05_weather_fair_night_l.png")
            if (code <= 2)  return p + (isDay ? "08_weather_partial_cloudy_day_l.png" : "09_weather_partial_cloudy_night_l.png")
            if (code === 3) return p + "01_weather_cloudy_l.png"
            if (code === 45 || code === 48) return p + "06_weather_foggy_l.png"
            if (code >= 95) return p + "16_weather_thunderstorm_l.png"
            if ((code >= 71 && code <= 77) || code === 85 || code === 86) return p + "02_weather_cloudy_with_snow_l.png"
            if (code === 66 || code === 67 || code === 56 || code === 57) return p + "12_weather_snow_rain_l.png"
            if (code >= 51) return p + "11_weather_rainy_l.png"
            return p + "01_weather_cloudy_l.png"
        }
        function wxText(code) {
            if (code === 0) return "Clear"; if (code === 1) return "Mostly clear"; if (code === 2) return "Partly cloudy"; if (code === 3) return "Overcast"
            if (code === 45 || code === 48) return "Fog"; if (code >= 95) return "Thunderstorm"
            if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "Snow"
            if (code >= 80) return "Showers"; if (code >= 61) return "Rain"; if (code >= 51) return "Drizzle"; return "Cloudy"
        }
        function dayName(iso) { var d = new Date(iso + "T12:00:00"); return ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][d.getDay()] }
        function fetchWeather() {
            var z = new XMLHttpRequest()
            z.onreadystatechange = function() {
                if (z.readyState !== 4) return
                var lat = 33.72, lon = -84.45, name = "Atlanta"
                try { var j = JSON.parse(z.responseText); lat = parseFloat(j.places[0].latitude); lon = parseFloat(j.places[0].longitude); name = j.places[0]["place name"] } catch (e) {}
                wxPlace.text = name
                var u = "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon +
                        "&current=temperature_2m,apparent_temperature,weather_code,is_day,relative_humidity_2m,wind_speed_10m" +
                        "&daily=weather_code,temperature_2m_max,temperature_2m_min&temperature_unit=" + units + "&wind_speed_unit=mph&timezone=auto&forecast_days=7"
                var x = new XMLHttpRequest()
                x.onreadystatechange = function() {
                    if (x.readyState !== 4) return
                    try {
                        var w = JSON.parse(x.responseText)
                        wxTemp.text = Math.round(w.current.temperature_2m) + "°"
                        wxCond.text = wxText(w.current.weather_code)
                        wxFeels.text = "Feels like " + Math.round(w.current.apparent_temperature) + "°  ·  " + w.current.relative_humidity_2m + "% humidity  ·  " + Math.round(w.current.wind_speed_10m) + " mph"
                        wxNow.source = "file://" + wxIcon(w.current.weather_code, w.current.is_day === 1)
                        var rows = []
                        for (var i = 0; i < w.daily.time.length; i++)
                            rows.push({ day: i === 0 ? "Today" : dayName(w.daily.time[i]), icon: "file://" + wxIcon(w.daily.weather_code[i], true),
                                        hi: Math.round(w.daily.temperature_2m_max[i]) + "°", lo: Math.round(w.daily.temperature_2m_min[i]) + "°" })
                        wxCard.allRows = rows; wxDaily.model = rows.slice(0, wxCard.maxDays)
                        wxCard.visible = true
                    } catch (e) { console.warn("[homeWidgets] weather parse failed: " + e) }
                }
                x.open("GET", u); x.send()
            }
            z.open("GET", "https://api.zippopotam.us/us/" + zip); z.send()
        }
        // ---------- news ----------
        function newsDecode(s) {
            return s.replace(/<!\[CDATA\[/g, "").replace(/\]\]>/g, "").replace(/<[^>]+>/g, "")
                    .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"")
                    .replace(/&#0?39;/g, "'").replace(/&apos;/g, "'").replace(/&nbsp;/g, " ")
                    .replace(/&amp;/g, "&").replace(/\s+/g, " ").trim()
        }
        function newsField(block, tag) {
            var m = new RegExp("<" + tag + "[^>]*>([\\s\\S]*?)<\\/" + tag + ">").exec(block)
            return m ? newsDecode(m[1]) : ""
        }
        function newsImage(block) {
            // Prefer the largest asset that is not wasteful to pull every slide. Some feeds publish
            // exactly one, oversized image (NYT ships a single 1800px square), so fall back to the
            // smallest of the oversized ones rather than showing no picture at all.
            var re = /<media:(?:content|thumbnail)([^>]*)>/g, m
            var best = "", bw = -1, over = "", ow = 0
            while ((m = re.exec(block)) !== null) {
                var u = /url="([^"]+)"/.exec(m[1]); if (!u) continue
                var w = /width="([0-9]+)"/.exec(m[1]), ww = w ? parseInt(w[1], 10) : 0
                if (ww <= 1200) { if (ww > bw) { bw = ww; best = u[1] } }
                else if (ow === 0 || ww < ow) { ow = ww; over = u[1] }
            }
            if (!best) best = over
            // BBC's ichef serves any width from the same path; the feed's 240px default is too soft here
            return best.replace(/\/standard\/[0-9]+\//, "/standard/480/")
        }
        function newsAgo(pub) {
            var t = Date.parse(pub); if (isNaN(t)) return ""
            var m = Math.round((Date.now() - t) / 60000)
            if (m < 1) return "now"
            if (m < 60) return m + "m ago"
            if (m < 1440) return Math.round(m / 60) + "h ago"
            return Math.round(m / 1440) + "d ago"
        }
        function newsParse(xml, feed) {
            var out = [], re = /<item>([\s\S]*?)<\/item>/g, m
            while ((m = re.exec(xml)) !== null && out.length < newsPerFeed) {
                var b = m[1], title = newsField(b, "title")
                if (!title) continue
                out.push({ tag: feed.tag, src: feed.src, title: title, body: newsField(b, "description"),
                           img: newsImage(b), ago: newsAgo(newsField(b, "pubDate")) })
            }
            return out
        }
        function newsMerge(buckets) {
            // Alternate world / US down the lists so the rotation never shows two of one region in
            // a row. The regional feeds overlap - a US story is usually in both - so drop repeats by
            // headline; feed order decides the badge, which is why world is listed first.
            var out = [], seen = {}, i = 0, more = true
            while (more) {
                more = false
                for (var b = 0; b < buckets.length; b++) {
                    var l = buckets[b] || []
                    if (i >= l.length) continue
                    more = true
                    var k = l[i].title.toLowerCase()
                    if (seen[k]) continue
                    seen[k] = true
                    out.push(l[i])
                }
                i++
            }
            return out
        }
        function newsLoad(feeds, onEmpty) {
            var buckets = [], pending = feeds.length
            for (var i = 0; i < feeds.length; i++) {
                (function(k) {
                    var x = new XMLHttpRequest()
                    x.onreadystatechange = function() {
                        if (x.readyState !== 4) return
                        try { buckets[k] = (x.status === 200) ? homeWidgets.newsParse(x.responseText, feeds[k]) : [] }
                        catch (e) { buckets[k] = []; console.warn("[homeWidgets] news parse failed: " + e) }
                        if (--pending > 0) return
                        var merged = homeWidgets.newsMerge(buckets)
                        // keep the previous slides rather than blanking the card on a failed refresh
                        if (!merged.length) { if (onEmpty) onEmpty(); return }
                        homeWidgets.newsItems = merged
                        if (homeWidgets.newsIndex >= merged.length) homeWidgets.newsIndex = 0
                        homeWidgets.newsApply(homeWidgets.newsIndex)
                        newsCard.visible = true
                    }
                    x.open("GET", feeds[k].url); x.send()
                })(i)
            }
        }
        function fetchNews() { newsLoad(newsFeeds, function() { homeWidgets.newsLoad(homeWidgets.newsFeedsAlt, null) }) }
        function newsApply(i) {
            var n = newsItems[i]; if (!n) return
            newsTag.text = n.tag
            newsMeta.text = n.src + (n.ago ? "  \u00b7  " + n.ago : "")
            newsTitle.text = n.title
            newsBodyText.text = n.body
            newsImg.source = n.img ? n.img : ""
        }
        function newsAdvance() {
            if (newsItems.length < 2) return
            newsIndex = (newsIndex + 1) % newsItems.length
            newsFade.restart()
        }
        Timer { interval: 1000; running: homeWidgets.visible; repeat: true; triggeredOnStart: true
            onTriggered: { var d = new Date(); clockText.text = homeWidgets.fmtTime(d); ampmText.text = homeWidgets.twelveHour ? (d.getHours() < 12 ? "AM" : "PM") : ""
                           dateText.text = Qt.formatDate(d, "dddd, MMMM d"); greetText.text = homeWidgets.greet(d) } }
        Timer { interval: 900000; running: homeWidgets.visible; repeat: true; triggeredOnStart: true; onTriggered: homeWidgets.fetchWeather() }
        Timer { interval: homeWidgets.newsSlideMs; running: homeWidgets.visible && homeWidgets.newsItems.length > 1; repeat: true; onTriggered: homeWidgets.newsAdvance() }
        Timer { interval: homeWidgets.newsRefreshMs; running: homeWidgets.visible; repeat: true; triggeredOnStart: true; onTriggered: homeWidgets.fetchNews() }

        // ---------- debug: compositor FPS (LG's own frame-swap counter) ----------
        property bool debugFps: true
        // frame counter straight from the compositor window: frames actually presented per second
        QtObject { id: fpsProbe; property int frames: 0; property int fps: 0 }
        Connections { target: homeWidgets.Window.window; onFrameSwapped: fpsProbe.frames++ }
        Timer { interval: 1000; running: true; repeat: true; onTriggered: { fpsProbe.fps = fpsProbe.frames; fpsProbe.frames = 0; console.info("[FPSLOG] glass " + fpsProbe.fps) } }
        Rectangle {
            visible: homeWidgets.debugFps
            x: parent.width - width - 24; y: parent.height - height - 20; z: 50
            width: fpsText.implicitWidth + 28; height: 34; radius: 8; color: "#a0100e1a"
            Text { id: fpsText; anchors.centerIn: parent; color: "#9ccfd8"; font.family: "LG Smart UI"; renderType: Text.NativeRendering; font.pixelSize: 18
                   text: "LSM " + fpsProbe.fps + " fps" }
        }

        // ---------- clock card ----------
        Item {
            id: clockCard
            x: homeWidgets.gx(homeWidgets.clockCol); y: homeWidgets.gridTop; width: homeWidgets.gw(homeWidgets.clockSpan); height: homeWidgets.gh(homeWidgets.clockRows)
            property bool small: width < 380 || height < 140
            // glass background is rendered by the compositor shader (cardA/cardB); content only here
            Text { id: greetText; visible: !clockCard.small && homeWidgets.clockStyle === "digital"; anchors.horizontalCenter: parent.horizontalCenter; y: 24; color: "#d4c4f0"; font.family: "LG Smart UI"; renderType: Text.NativeRendering; font.pixelSize: 22; style: Text.Raised; styleColor: "#40000000" }
            Row { visible: homeWidgets.clockStyle === "digital"; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: clockCard.small ? (parent.height - clockText.height) / 2 : 46; spacing: 8
                Text { id: clockText; color: "#e0def4"; font.family: "LG Smart UI"; renderType: Text.NativeRendering; font.pixelSize: clockCard.small ? 54 : 66; font.weight: Font.Light; style: Text.Raised; styleColor: "#50000000" }
                Text { id: ampmText; color: "#908caa"; font.family: "LG Smart UI"; renderType: Text.NativeRendering; font.pixelSize: 24; anchors.baseline: clockText.baseline } }
            Text { id: dateText; visible: !clockCard.small && homeWidgets.clockStyle === "digital"; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 20; color: "#e0def4"; opacity: 0.8; font.family: "LG Smart UI"; renderType: Text.NativeRendering; font.pixelSize: 20 }

            // ---- analog face (GPU-cheap: rotated rectangles, no Canvas) ----
            Item {
                id: analog
                visible: homeWidgets.clockStyle === "analog"
                anchors.fill: parent
                property real dia: Math.min(parent.width, parent.height) - 64
                property real sec: 0; property real min: 0; property real hr: 0
                Timer { interval: 1000; running: analog.visible; repeat: true; triggeredOnStart: true
                    onTriggered: { var d = new Date(); analog.sec = d.getSeconds() * 6; analog.min = d.getMinutes() * 6 + d.getSeconds() * 0.1; analog.hr = (d.getHours() % 12) * 30 + d.getMinutes() * 0.5 } }
                Text { anchors.top: parent.top; anchors.topMargin: 22; anchors.left: parent.left; anchors.leftMargin: 32; text: greetText.text; color: "#d4c4f0"; font.family: "LG Smart UI"; renderType: Text.NativeRendering; font.pixelSize: 22 }
                Text { anchors.bottom: parent.bottom; anchors.bottomMargin: 20; anchors.left: parent.left; anchors.leftMargin: 32; text: dateText.text; color: "#e0def4"; opacity: 0.8; font.family: "LG Smart UI"; renderType: Text.NativeRendering; font.pixelSize: 20 }
                Text { anchors.bottom: parent.bottom; anchors.bottomMargin: 20; anchors.right: parent.right; anchors.rightMargin: 32; text: clockText.text + " " + ampmText.text; color: "#e0def4"; opacity: 0.8; font.family: "LG Smart UI"; renderType: Text.NativeRendering; font.pixelSize: 20 }
                Item {
                    id: face
                    width: analog.dia; height: analog.dia; anchors.centerIn: parent
                    Rectangle { anchors.fill: parent; radius: width / 2; color: "#e0def4"; opacity: 0.06; border.color: "#e0def4"; border.width: 1; antialiasing: true }
                    Repeater { model: 12
                        Rectangle { width: index % 3 === 0 ? 3 : 2; height: index % 3 === 0 ? 14 : 8; radius: 1; color: "#e0def4"; opacity: index % 3 === 0 ? 0.9 : 0.45
                            x: face.width / 2 - width / 2; y: 10
                            transform: Rotation { origin.x: width / 2; origin.y: face.height / 2 - 10; angle: index * 30 } } }
                    Rectangle { id: hHand; width: 6; height: face.height * 0.26; radius: 3; color: "#e0def4"; antialiasing: true
                        x: face.width / 2 - 3; y: face.height / 2 - height + 8
                        transform: Rotation { origin.x: 3; origin.y: hHand.height - 8; angle: analog.hr } }
                    Rectangle { id: mHand; width: 4; height: face.height * 0.38; radius: 2; color: "#e0def4"; antialiasing: true
                        x: face.width / 2 - 2; y: face.height / 2 - height + 10
                        transform: Rotation { origin.x: 2; origin.y: mHand.height - 10; angle: analog.min } }
                    Rectangle { id: sHand; width: 2; height: face.height * 0.42; radius: 1; color: "#ebbcba"; antialiasing: true
                        x: face.width / 2 - 1; y: face.height / 2 - height + 22
                        transform: Rotation { origin.x: 1; origin.y: sHand.height - 22; angle: analog.sec } }
                    Rectangle { width: 12; height: 12; radius: 6; color: "#ebbcba"; anchors.centerIn: parent }
                    Rectangle { width: 5; height: 5; radius: 2.5; color: "#191724"; anchors.centerIn: parent }
                }
            }
        }

        // ---------- weather card ----------
        Item {
            id: wxCard
            visible: false
            x: homeWidgets.gx(homeWidgets.wxCol); y: homeWidgets.gridTop; width: homeWidgets.gw(homeWidgets.wxSpan); height: homeWidgets.gh(homeWidgets.wxRows)
            property bool narrow: width < 400
            property bool showDetails: height >= 260 && !narrow          // feels/humidity line
            property int  forecastTop: showDetails ? 226 : 176
            property real avail: height - forecastTop - 20
            property int  maxDays: Math.min(7, Math.max(0, Math.floor(avail / 46)))
            property real rowPx: maxDays > 0 ? Math.min(62, Math.floor(avail / maxDays)) : 46
            property var  allRows: []
            onMaxDaysChanged: if (allRows.length) wxDaily.model = allRows.slice(0, maxDays)
            // glass background is rendered by the compositor shader (cardA/cardB); content only here

            Text { id: wxPlace; x: 32; y: 24; color: "#d4c4f0"; font.family: "LG Smart UI"; renderType: Text.NativeRendering; font.pixelSize: 22 }
            Image { id: wxNow; x: 28; y: 52; width: 104; height: 104; fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true }
            Text { id: wxTemp; x: 146; y: 46; color: "#e0def4"; font.family: "LG Smart UI"; renderType: Text.NativeRendering; font.pixelSize: wxCard.narrow ? 60 : 78; font.weight: Font.Light; style: Text.Raised; styleColor: "#50000000" }
            Text { id: wxCond; x: 150; y: 136; color: "#ebbcba"; font.family: "LG Smart UI"; renderType: Text.NativeRendering; font.pixelSize: 24 }
            Text { id: wxFeels; visible: wxCard.showDetails; x: 32; y: 176; width: parent.width - 64; color: "#e0def4"; opacity: 0.75; font.family: "LG Smart UI"; renderType: Text.NativeRendering; font.pixelSize: 17; elide: Text.ElideRight }
            Rectangle { visible: wxCard.maxDays > 0; x: 32; y: wxCard.forecastTop - 14; width: parent.width - 64; height: 1; color: "#e0def4"; opacity: 0.14 }

            Column {
                x: 32; y: wxCard.forecastTop; width: parent.width - 64; spacing: 0
                visible: wxCard.maxDays > 0
                Repeater {
                    id: wxDaily
                    delegate: Item {
                        width: parent.width; height: wxCard.rowPx
                        Text { x: 0; anchors.verticalCenter: parent.verticalCenter; width: 92; text: modelData.day; color: "#e0def4"; font.family: "LG Smart UI"; renderType: Text.NativeRendering; font.pixelSize: 20; opacity: index === 0 ? 1 : 0.85 }
                        Image { x: 112; anchors.verticalCenter: parent.verticalCenter; width: 34; height: 34; source: modelData.icon; fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true }
                        Text { anchors.right: parent.right; anchors.rightMargin: 64; anchors.verticalCenter: parent.verticalCenter; text: modelData.hi; color: "#e0def4"; font.family: "LG Smart UI"; renderType: Text.NativeRendering; font.pixelSize: 20; horizontalAlignment: Text.AlignRight; width: 44 }
                        Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: modelData.lo; color: "#b9b5cf"; font.family: "LG Smart UI"; renderType: Text.NativeRendering; font.pixelSize: 20; horizontalAlignment: Text.AlignRight; width: 44 }
                    }
                }
            }
        }

        // ---------- news card (bottom-left, sits above the dock band) ----------
        Item {
            id: newsCard
            visible: false
            x: homeWidgets.gx(homeWidgets.newsCol)
            width: homeWidgets.gw(homeWidgets.newsSpan)
            height: homeWidgets.gh(homeWidgets.newsRows)
            y: homeKey.dockRect.y - homeWidgets.newsDockGap - height
            property real pad: 28
            property real imgW: Math.round(width * 0.34)
            property bool hasImg: newsImg.status === Image.Ready
            property real textX: pad + (hasImg ? imgW + 24 : 0)
            // glass background is rendered by the compositor shader (cardC); content only here

            SequentialAnimation {
                id: newsFade
                NumberAnimation { target: newsBody; property: "opacity"; to: 0; duration: 220; easing.type: Easing.InQuad }
                ScriptAction { script: homeWidgets.newsApply(homeWidgets.newsIndex) }
                NumberAnimation { target: newsBody; property: "opacity"; to: 1; duration: 320; easing.type: Easing.OutQuad }
            }

            Item {
                id: newsBody
                anchors.fill: parent

                Item {
                    // photo, cropped to the card's proportions and rounded to match the glass corners
                    x: newsCard.pad; y: newsCard.pad
                    width: newsCard.imgW; height: newsCard.height - 2 * newsCard.pad
                    visible: newsCard.hasImg
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle { width: newsCard.imgW; height: newsCard.height - 2 * newsCard.pad; radius: 16 }
                    }
                    Image {
                        id: newsImg
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        smooth: true; mipmap: true; asynchronous: true; cache: true
                    }
                }

                Column {
                    // centred, and the block shrinks to its content, so a one-sentence summary
                    // reads as deliberate rather than leaving the lower half of the card empty
                    id: newsText
                    x: newsCard.textX
                    width: newsCard.width - newsCard.textX - newsCard.pad
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14
                    Row {
                        id: newsHead
                        spacing: 12
                        Rectangle {
                            width: newsTag.implicitWidth + 20; height: 25; radius: 6
                            color: newsTag.text === "U.S." ? "#40eb6f92" : "#40c4a7e7"
                            border.width: 1
                            border.color: newsTag.text === "U.S." ? "#80eb6f92" : "#80c4a7e7"
                            Text {
                                id: newsTag
                                anchors.centerIn: parent
                                color: "#e8e4f4"; font.family: "LG Smart UI"; renderType: Text.NativeRendering
                                font.pixelSize: 14; font.letterSpacing: 1.2
                            }
                        }
                        Text {
                            id: newsMeta
                            anchors.verticalCenter: parent.verticalCenter
                            color: "#d4c4f0"; opacity: 0.8
                            font.family: "LG Smart UI"; renderType: Text.NativeRendering; font.pixelSize: 16
                        }
                    }
                    Text {
                        id: newsTitle
                        width: parent.width
                        color: "#e8e4f4"; font.family: "LG Smart UI"; renderType: Text.NativeRendering
                        font.pixelSize: 28; font.weight: Font.DemiBold; lineHeight: 1.15
                        wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight
                        style: Text.Raised; styleColor: "#50000000"
                    }
                    Text {
                        id: newsBodyText
                        width: parent.width
                        // as much of the summary as the space the headline left over will hold
                        property real avail: Math.max(0, newsCard.height - 2 * newsCard.pad
                                                         - newsHead.height - newsTitle.height - 2 * newsText.spacing)
                        maximumLineCount: Math.max(1, Math.floor(avail / 26))
                        height: Math.min(implicitHeight, avail)
                        color: "#cdc7e0"; opacity: 0.9
                        font.family: "LG Smart UI"; renderType: Text.NativeRendering
                        font.pixelSize: 20; lineHeight: 1.3
                        wrapMode: Text.WordWrap; elide: Text.ElideRight
                    }
                }
            }

            Row {
                // slide position; outside newsBody so it does not fade with the content
                anchors.right: parent.right; anchors.rightMargin: newsCard.pad
                anchors.bottom: parent.bottom; anchors.bottomMargin: newsCard.pad - 8
                spacing: 7
                Repeater {
                    model: homeWidgets.newsItems.length
                    delegate: Rectangle {
                        width: 6; height: 6; radius: 3; color: "#e0def4"
                        opacity: index === homeWidgets.newsIndex ? 0.95 : 0.26
                        Behavior on opacity { NumberAnimation { duration: 250 } }
                    }
                }
            }
        }
    }

    // ===== static glass bake: wallpaper + dock + pill + cards, rendered ONCE (inputs never change per frame) =====
    ShaderEffect {
        id: glassBake
        anchors.fill: parent
        visible: false
        property variant wall: homeWallSrc
        property variant wallb: homeWallBlurSrc
        property real px: 1.0 / Math.max(1, width)
        property real py: 1.0 / Math.max(1, height)
        property vector4d dockV: homeKey.dockV
        property vector4d railV: homeKey.railV
        property real railR: homeKey.railR
        property real glassLift: homeKey.glassLift
        property real aspect: homeKey.aspect
        property vector3d tintV: homeKey.tintV
        property vector3d rimV: homeKey.rimV
        property real glassTintAmount: homeKey.glassTintAmount
        property vector4d cardAV: homeKey.cardAV
        property vector4d cardBV: homeKey.cardBV
        property real cardR: homeKey.cardR
        property real cardBAmt: homeKey.cardBAmt
        property vector4d cardCV: homeKey.cardCV
        property real cardCAmt: homeKey.cardCAmt
        property variant src: homeWallSrc   // unused by the bake, keeps isW() compiling
        fragmentShader: "
            varying highp vec2 qt_TexCoord0;
            uniform sampler2D src;
            uniform sampler2D wall;
            uniform lowp float qt_Opacity;
            uniform highp float px;
            uniform highp float py;
            uniform sampler2D wallb;
            uniform highp vec4 dockV;
            uniform highp vec4 railV;
            uniform highp float railR;
            uniform highp float glassLift;
            uniform highp float aspect;
            uniform highp vec3 tintV;
            uniform highp vec3 rimV;
            uniform highp float glassTintAmount;
            uniform highp vec4 cardAV;
            uniform highp vec4 cardBV;
            uniform highp float cardR;
            uniform highp float cardBAmt;
            uniform highp vec4 cardCV;
            uniform highp float cardCAmt;
lowp float isW(highp vec2 uv) { lowp vec4 s = texture2D(src, uv); return step(0.995, min(s.r, min(s.g, s.b))) * step(0.5, s.a); }
            // signed distance to a rounded rect, in height-normalised units (aspect-corrected); negative = inside
            highp float sdRR(highp vec2 uv, highp vec4 r, highp float rad) {
                highp vec2 c = vec2((r.x + r.z * 0.5) * aspect, r.y + r.w * 0.5);
                highp vec2 h = vec2(r.z * 0.5 * aspect, r.w * 0.5) - vec2(rad);
                highp vec2 p = vec2(uv.x * aspect, uv.y) - c;
                highp vec2 d = abs(p) - h;
                return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - rad;
            }
            highp vec2 sdGrad(highp vec2 uv, highp vec4 r, highp float rad) {   // outward normal of the shape
                highp float e = 0.0015;
                highp float dx = sdRR(uv + vec2(e / aspect, 0.0), r, rad) - sdRR(uv - vec2(e / aspect, 0.0), r, rad);
                highp float dy = sdRR(uv + vec2(0.0, e), r, rad) - sdRR(uv - vec2(0.0, e), r, rad);
                highp vec2 g = vec2(dx, dy); highp float l = length(g); return l > 0.0 ? g / l : vec2(0.0);
            }
            // Liquid-glass material: dark tint over a true-gaussian backdrop, with a physically-lit bevel.
            // The edge has a quarter-round profile (width ~22px); its normal drives refraction, a Blinn
            // specular from a top-left key light, and a Fresnel rim. Inside the shape the surface is flat.
            lowp vec4 glassSample(highp vec2 uv, highp vec4 r, highp float rad, highp float d, highp float hn) {
                highp vec2 n = sdGrad(uv, r, rad);
                highp float w = 0.0085;
                highp float t = clamp(-d / w, 0.0, 1.0);                  // 0 at rim .. 1 flat interior
                highp float e = 1.0 - t;
                highp float z = sqrt(max(0.0, 1.0 - e * e));              // profile height (quarter circle)
                highp vec3 N = normalize(vec3(-n * e * 1.6, z + 0.25));   // surface normal (z up, toward viewer)
                // refraction: the bevel bends the backdrop inward; slight chromatic split
                highp vec2 off = -n * (1.0 - z) * 0.005 * vec2(1.0 / aspect, 1.0);
                highp vec2 ca  = -n * (1.0 - z) * 0.0006 * vec2(1.0 / aspect, 1.0);
                lowp vec4 b;
                b.r = texture2D(wallb, uv + off + ca).r;
                b.g = texture2D(wallb, uv + off).g;
                b.b = texture2D(wallb, uv + off - ca).b;
                b.a = 1.0;
                b.rgb = mix(b.rgb, tintV, glassTintAmount);
                b.rgb = mix(b.rgb, vec3(1.0), 0.012);
                highp float top = clamp((r.y + r.w - uv.y) / max(r.w, 0.0001), 0.0, 1.0);
                b.rgb += vec3(0.018) * top * top;
                // lighting on the bevel
                highp vec3 L = normalize(vec3(-0.45, -0.80, 0.55));
                highp vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
                highp float lit = 0.25 + 0.75 * clamp(-n.y, 0.0, 1.0);
                highp float spec = pow(max(dot(N, H), 0.0), 48.0) * 0.26 * (1.0 - t) * lit;
                highp float fres = pow(1.0 - clamp(N.z, 0.0, 1.0), 3.0) * 0.07 * lit;
                highp float diff = 0.0;
                b.rgb += (spec + fres + diff) * rimV;
                // crisp 1.6px edge line for definition, with a faint darker inner edge on the shadow side
                highp float s1 = 1.6 / 1080.0;
                highp float rimA = exp(-(d * d) / (2.0 * s1 * s1)) * step(d, 0.0);
                b.rgb += rimA * (0.05 + 0.16 * clamp(-n.y, 0.0, 1.0)) * rimV;
                highp float dIn = d + 2.2 / 1080.0;
                highp float edgeA = exp(-(dIn * dIn) / (2.0 * s1 * s1)) * step(d, 0.0);
                b.rgb *= 1.0 - edgeA * (0.04 + 0.08 * clamp(n.y, 0.0, 1.0));
                b.rgb += (hn - 0.5) * (2.0 / 255.0);
                return b;
            }
            // 4-tap supersampled coverage of a rounded rect (anti-aliased edge)
            lowp float coverRR(highp vec2 uv, highp vec4 r, highp float rad) {
                highp vec2 o = vec2(0.25 * px, 0.25 * py);
                lowp float c = 0.0;
                c += step(sdRR(uv + vec2( o.x,  o.y), r, rad), 0.0);
                c += step(sdRR(uv + vec2(-o.x,  o.y), r, rad), 0.0);
                c += step(sdRR(uv + vec2( o.x, -o.y), r, rad), 0.0);
                c += step(sdRR(uv + vec2(-o.x, -o.y), r, rad), 0.0);
                return c * 0.25;
            }
            void main() {
                lowp vec4 w = texture2D(wall, qt_TexCoord0);
                highp float hn = fract(sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453);
                w.rgb += (hn - 0.5) * (2.0 / 255.0);
                highp float dDock = sdRR(qt_TexCoord0, dockV, 0.0);
                lowp float gDock = coverRR(qt_TexCoord0, dockV, 0.0);
                if (gDock > 0.0) w = mix(w, glassSample(qt_TexCoord0, dockV, 0.0, dDock, hn), gDock);
                highp float dRail = sdRR(qt_TexCoord0, railV, railR);
                lowp float gRail = coverRR(qt_TexCoord0, railV, railR);
                if (gRail > 0.0) w = mix(w, glassSample(qt_TexCoord0, railV, railR, dRail, hn), gRail);
                highp float dA = sdRR(qt_TexCoord0, cardAV, cardR);
                lowp float gA = coverRR(qt_TexCoord0, cardAV, cardR);
                if (gA > 0.001) w = mix(w, glassSample(qt_TexCoord0, cardAV, cardR, dA, hn), gA);
                highp float dB = sdRR(qt_TexCoord0, cardBV, cardR);
                lowp float gB = coverRR(qt_TexCoord0, cardBV, cardR) * cardBAmt;
                if (gB > 0.001) w = mix(w, glassSample(qt_TexCoord0, cardBV, cardR, dB, hn), gB);
                highp float dC = sdRR(qt_TexCoord0, cardCV, cardR);
                lowp float gC = coverRR(qt_TexCoord0, cardCV, cardR) * cardCAmt;
                if (gC > 0.001) w = mix(w, glassSample(qt_TexCoord0, cardCV, cardR, dC, hn), gC);
                gl_FragColor = vec4(w.rgb, 1.0);
            }"
    }
    ShaderEffectSource { id: glassBakeSrc; sourceItem: glassBake; anchors.fill: parent; visible: false; live: true }

    ShaderEffect {
        id: homeKey
        anchors.fill: parent
        z: 1
        visible: root.homeKeyOn
        property variant src: homeSurfSrc
        property variant wall: glassBakeSrc
        property variant wallb: homeWallBlurSrc
        // live glass regions (px): dock band + rail pill. Adjustable at runtime.
        property rect dockRect: Qt.rect(-80, 812, 2080, 200)
        property rect railRect: Qt.rect(26, 42, 104, 360)
        property real railRadius: railRect.width / 2
        property real glassLift: 0.11
        // tint derived from the wallpaper (mean hue, dark value); rim is a light version of the same hue
        property color glassTint: "#1e1a24"
        property color glassRim: "#e3d8f5"
        property real glassTintAmount: 0.40
        property vector3d tintV: Qt.vector3d(glassTint.r, glassTint.g, glassTint.b)
        property vector3d rimV: Qt.vector3d(glassRim.r, glassRim.g, glassRim.b)
        property vector4d dockV: Qt.vector4d(dockRect.x / width, dockRect.y / height, dockRect.width / width, dockRect.height / height)
        property vector4d railV: Qt.vector4d(railRect.x / width, railRect.y / height, railRect.width / width, railRect.height / height)
        property real railR: railRadius / height
        // rail icon slots (px, 1080p): centre x, first centre y, pitch, count, LG focus-square half size
        property real slotX: 78; property real slotY0: 93; property real slotPitch: 86; property int slotCount: 4; property real slotHalf: 31
        property rect cardA: Qt.rect(clockCard.x, clockCard.y, clockCard.width, clockCard.height)
        property rect cardB: Qt.rect(wxCard.x, wxCard.y, wxCard.width, wxCard.height)
        property bool cardBOn: wxCard.visible
        property real cardRadius: 28
        property vector4d cardAV: Qt.vector4d(cardA.x / width, cardA.y / height, cardA.width / width, cardA.height / height)
        property vector4d cardBV: Qt.vector4d(cardB.x / width, cardB.y / height, cardB.width / width, cardB.height / height)
        property real cardR: cardRadius / height
        property real cardBAmt: cardBOn ? 1.0 : 0.0
        property rect cardC: Qt.rect(newsCard.x, newsCard.y, newsCard.width, newsCard.height)
        property bool cardCOn: newsCard.visible
        property vector4d cardCV: Qt.vector4d(cardC.x / width, cardC.y / height, cardC.width / width, cardC.height / height)
        property real cardCAmt: cardCOn ? 1.0 : 0.0
        property vector4d slotV: Qt.vector4d(slotX / width, slotY0 / height, slotPitch / height, slotHalf / height)
        property real aspect: width / height
        property real px: 1.0 / Math.max(1, width)
        property real py: 1.0 / Math.max(1, height)
        fragmentShader: "
            varying highp vec2 qt_TexCoord0;
            uniform sampler2D src;
            uniform sampler2D wall;
            uniform lowp float qt_Opacity;
            uniform highp float px;
            uniform highp float py;
            uniform sampler2D wallb;
            uniform highp vec4 dockV;
            uniform highp vec4 railV;
            uniform highp float railR;
            uniform highp float glassLift;
            uniform highp vec3 tintV;
            uniform highp vec3 rimV;
            uniform highp float glassTintAmount;
            uniform highp vec4 slotV;
            uniform highp vec4 cardAV;
            uniform highp vec4 cardBV;
            uniform highp float cardR;
            uniform highp float cardBAmt;
            uniform highp float aspect;
            lowp float isW(highp vec2 uv) { lowp vec4 s = texture2D(src, uv); return step(0.995, min(s.r, min(s.g, s.b))) * step(0.5, s.a); }
            // signed distance to a rounded rect, in height-normalised units (aspect-corrected); negative = inside
            highp float sdRR(highp vec2 uv, highp vec4 r, highp float rad) {
                highp vec2 c = vec2((r.x + r.z * 0.5) * aspect, r.y + r.w * 0.5);
                highp vec2 h = vec2(r.z * 0.5 * aspect, r.w * 0.5) - vec2(rad);
                highp vec2 p = vec2(uv.x * aspect, uv.y) - c;
                highp vec2 d = abs(p) - h;
                return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - rad;
            }
            highp vec2 sdGrad(highp vec2 uv, highp vec4 r, highp float rad) {   // outward normal of the shape
                highp float e = 0.0015;
                highp float dx = sdRR(uv + vec2(e / aspect, 0.0), r, rad) - sdRR(uv - vec2(e / aspect, 0.0), r, rad);
                highp float dy = sdRR(uv + vec2(0.0, e), r, rad) - sdRR(uv - vec2(0.0, e), r, rad);
                highp vec2 g = vec2(dx, dy); highp float l = length(g); return l > 0.0 ? g / l : vec2(0.0);
            }
            // Liquid-glass material: dark tint over a true-gaussian backdrop, with a physically-lit bevel.
            // The edge has a quarter-round profile (width ~22px); its normal drives refraction, a Blinn
            // specular from a top-left key light, and a Fresnel rim. Inside the shape the surface is flat.
            lowp vec4 glassSample(highp vec2 uv, highp vec4 r, highp float rad, highp float d, highp float hn) {
                highp vec2 n = sdGrad(uv, r, rad);
                highp float w = 0.0085;
                highp float t = clamp(-d / w, 0.0, 1.0);                  // 0 at rim .. 1 flat interior
                highp float e = 1.0 - t;
                highp float z = sqrt(max(0.0, 1.0 - e * e));              // profile height (quarter circle)
                highp vec3 N = normalize(vec3(-n * e * 1.6, z + 0.25));   // surface normal (z up, toward viewer)
                // refraction: the bevel bends the backdrop inward; slight chromatic split
                highp vec2 off = -n * (1.0 - z) * 0.005 * vec2(1.0 / aspect, 1.0);
                highp vec2 ca  = -n * (1.0 - z) * 0.0006 * vec2(1.0 / aspect, 1.0);
                lowp vec4 b;
                b.r = texture2D(wallb, uv + off + ca).r;
                b.g = texture2D(wallb, uv + off).g;
                b.b = texture2D(wallb, uv + off - ca).b;
                b.a = 1.0;
                b.rgb = mix(b.rgb, tintV, glassTintAmount);
                b.rgb = mix(b.rgb, vec3(1.0), 0.012);
                highp float top = clamp((r.y + r.w - uv.y) / max(r.w, 0.0001), 0.0, 1.0);
                b.rgb += vec3(0.018) * top * top;
                // lighting on the bevel
                highp vec3 L = normalize(vec3(-0.45, -0.80, 0.55));
                highp vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
                highp float lit = 0.25 + 0.75 * clamp(-n.y, 0.0, 1.0);
                highp float spec = pow(max(dot(N, H), 0.0), 48.0) * 0.26 * (1.0 - t) * lit;
                highp float fres = pow(1.0 - clamp(N.z, 0.0, 1.0), 3.0) * 0.07 * lit;
                highp float diff = 0.0;
                b.rgb += (spec + fres + diff) * rimV;
                // crisp 1.6px edge line for definition, with a faint darker inner edge on the shadow side
                highp float s1 = 1.6 / 1080.0;
                highp float rimA = exp(-(d * d) / (2.0 * s1 * s1)) * step(d, 0.0);
                b.rgb += rimA * (0.05 + 0.16 * clamp(-n.y, 0.0, 1.0)) * rimV;
                highp float dIn = d + 2.2 / 1080.0;
                highp float edgeA = exp(-(dIn * dIn) / (2.0 * s1 * s1)) * step(d, 0.0);
                b.rgb *= 1.0 - edgeA * (0.04 + 0.08 * clamp(n.y, 0.0, 1.0));
                b.rgb += (hn - 0.5) * (2.0 / 255.0);
                return b;
            }
            // 4-tap supersampled coverage of a rounded rect (anti-aliased edge)
            lowp float coverRR(highp vec2 uv, highp vec4 r, highp float rad) {
                highp vec2 o = vec2(0.25 * px, 0.25 * py);
                lowp float c = 0.0;
                c += step(sdRR(uv + vec2( o.x,  o.y), r, rad), 0.0);
                c += step(sdRR(uv + vec2(-o.x,  o.y), r, rad), 0.0);
                c += step(sdRR(uv + vec2( o.x, -o.y), r, rad), 0.0);
                c += step(sdRR(uv + vec2(-o.x, -o.y), r, rad), 0.0);
                return c * 0.25;
            }
            void main() {
                lowp vec4 c = texture2D(src, qt_TexCoord0);
                lowp vec4 w = texture2D(wall, qt_TexCoord0);                 // pre-baked wallpaper + static glass
                lowp float isBlack = step(max(c.r, max(c.g, c.b)), 0.003) * step(0.5, c.a);
                lowp vec4 col = mix(c, w, isBlack);
                lowp float inRail = step(qt_TexCoord0.x, 0.082) * step(qt_TexCoord0.y, 0.42);
                if (inRail > 0.5) {
                    highp float hn = fract(sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453);
                    highp float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
                    highp float lumc = dot(c.rgb, vec3(0.299, 0.587, 0.114));
                    if (isBlack < 0.5 && sat < 0.08 && lumc < 0.985 && c.a > 0.5) col = mix(w, vec4(1.0), lumc);
                    highp float idx = clamp(floor((qt_TexCoord0.y - slotV.y) / slotV.z + 0.5), 0.0, 3.0);
                    highp float cy = slotV.y + idx * slotV.z;
                    highp float cx = slotV.x;
                    highp float hs = slotV.w + 4.0 / 1080.0;
                    highp vec2 pc = vec2((qt_TexCoord0.x - cx) * aspect, qt_TexCoord0.y - cy);
                    if (abs(pc.x) <= hs && abs(pc.y) <= hs) {
                        highp float o = slotV.w * 0.72;
                        lowp float present = isW(vec2(cx - o / aspect, cy - o)) + isW(vec2(cx + o / aspect, cy - o)) + isW(vec2(cx - o / aspect, cy + o)) + isW(vec2(cx + o / aspect, cy + o));
                        if (present >= 2.0) {
                            highp float rad = slotV.w * 0.92;
                            highp float dd = length(pc) - rad;
                            highp float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
                            highp float ink = (1.0 - smoothstep(0.30, 0.92, lum)) * step(0.5, c.a);
                            lowp float inDisc = 1.0 - smoothstep(-0.6 / 1080.0, 0.6 / 1080.0, dd);
                            if (inDisc > 0.001) {
                                highp float t = clamp(1.0 + dd / (rad * 0.55), 0.0, 1.0);
                                highp vec2 dir = length(pc) > 0.0 ? pc / length(pc) : vec2(0.0);
                                highp vec2 mag = qt_TexCoord0 - pc * vec2(1.0 / aspect, 1.0) * 0.12;
                                highp vec2 bend = -dir * t * t * 0.004 * vec2(1.0 / aspect, 1.0);
                                lowp vec4 lens = texture2D(wallb, mag + bend);
                                lens.rgb = mix(lens.rgb, tintV, glassTintAmount * 0.35);
                                lens.rgb = mix(lens.rgb, vec3(1.0), 0.10);
                                highp float rimA = exp(-(dd * dd) / (2.0 * (2.2 / 1080.0) * (2.2 / 1080.0)));
                                highp float lobe = 0.10 + 0.55 * clamp(-dir.y, 0.0, 1.0) + 0.16 * clamp(dir.y, 0.0, 1.0);
                                lens.rgb += rimA * lobe * rimV;
                                highp vec2 hp = pc - vec2(-0.30, -0.42) * rad;
                                lens.rgb += rimV * 0.16 * exp(-dot(hp, hp) / (2.0 * rad * rad * 0.08));
                                lens.rgb += (hn - 0.5) * (2.0 / 255.0);
                                lens = mix(lens, vec4(0.922, 0.737, 0.729, 1.0), ink);
                                col = mix(w, lens, inDisc);
                            } else {
                                col = w;
                            }
                        }
                    }
                }
                gl_FragColor = col * qt_Opacity;
            }"
    }


    StarfishFullscreenStandby {
        id : fullscreenCover
        anchors.fill: parent
        visible: false

        onVisibleChanged : {
            console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] Cover UI visible is changed = " + fullscreenCover.visible )
        }
    }

    StarfishServerDecoration {
        id: ssd
        enabled: false
        z: root.z + 1
        isMultiViewMode: root.isMultiViewMode()
        isMultiViewLandscapeMode: root.isMultiViewLandscapeMode()
        fullscreenCoverVisible: fullscreenCover.visible
        containerVisible: root.visibleState
        controlMode: root.controlMode
        itemContainsMouse: root.surfaceItemContainsMouse
        onRequestGoNextDecoration: {
            if (!root.__layoutInfo.isPipSub) {
                root.focusedDecoration(order, direction)
            }
        }
        onRequestShowToolbar: root.requestShowToolbar(order, delayed, root.mode())
        onRequestHideDecorations: root.setShowToolbarStatus(false) // by backkey
        expireTimer.onTriggered: root.setShowToolbarStatus(false) //by timer
    }

    Rectangle {
        id: controllerModeGuide
        visible: root.controlMode && root.fitOnParent && controlModeGuideTimer.running && !emptyCurrentItem() && ssd.__config.controlModeGuideUI
        anchors.bottom: root.bottom
        width: root.width
        height: Settings.local.multiviewControlMode.bgHeight
        color: "transparent"
        onVisibleChanged: {
            if (visible) {
                views.fullscreen.requestTts(root.controllerModeGuideStr, 1, true)
            }
        }

        Rectangle {
            id: bgImage
            anchors.fill: parent
            color: Settings.local.multiviewControlMode.bgColor
            opacity: Settings.local.multiviewControlMode.opacity
        }

        Text {
            id: guideText
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: root.languageStyle.normal400.fontFamily[0]
            font.pixelSize: Settings.local.multiviewControlMode.fontSize
            color: Settings.local.multiviewControlMode.fontColor
            text: root.controllerModeGuideStr
        }
    }

    function __debugState() {
        return {
            "surfaceItem": (root.__surfaceItem ? root.__surfaceItem.appId : "empty"),
            "layoutInfo": {
                "appId": root.__layoutInfo.appId,
                "mode": root.__layoutInfo.mode,
                "order": root.__layoutInfo.order,
                "x": root.__layoutInfo.x,
                "y": root.__layoutInfo.y,
                "z": root.__layoutInfo.z,
                "width": root.__layoutInfo.width,
                "height": root.__layoutInfo.height,
                "multiviewOrientation": root.__layoutInfo.multiviewOrientation,
                "controlMode": root.controlMode
            }
        }
    }

    function __debugSSD() {
        return ssd
    }

    function __debugAnimator() {
        return containerAnimator
    }

    function nextAppId() {
        return root.__layoutInfo.appId
    }

    function resetNextLayoutInfo() {
        console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] reset next layout info")
        if (fullscreenCover.visible) {
            console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] Delay to reset layout info")
            root.__pendingLayoutInfo.isPending = true
            root.__pendingLayoutInfo.needReset = true
        } else {
            root.__layoutInfo.reset()
            layoutInfoUpdated()
        }
    }

    function setNextLayout(mode, usageType, requestedLayoutInfo, isPipSub = false, changedExceptGeometry) {

        console.info("[FULLSCREEN][" + root.objectName + "][" + requestedLayoutInfo.order + "] setNextLayout", requestedLayoutInfo.appId, mode, usageType,
                    requestedLayoutInfo.x, requestedLayoutInfo.y, requestedLayoutInfo.width, requestedLayoutInfo.height,
                    requestedLayoutInfo.orientation, isPipSub, changedExceptGeometry)

        root.setShowToolbarStatus(false)

        if (bgBlack.visible === false) {
            if (root.__layoutInfo.appId !== "" && requestedLayoutInfo.appId !== root.__layoutInfo.appId) {
                Utils.pmLog.info("SVU_LSM_BG_BLACK", {}, "[FULLSCREEN][" + root.objectName + "][" + requestedLayoutInfo.order + "] set bgBlack true by layout appid is changed. " + root.__layoutInfo.appId + " -> " + requestedLayoutInfo.appId);
                bgBlack.visible = true
            }
            if (isPipSub === true) {
                Utils.pmLog.info("SVU_LSM_BG_BLACK", {}, "[FULLSCREEN][" + root.objectName + "][" + requestedLayoutInfo.order + "] set bgBlack true by layout is pip & sub");
                bgBlack.visible = true
            }
        }

        if (changedExceptGeometry === undefined) {
            if (root.__layoutInfo.appId === requestedLayoutInfo.appId && root.__layoutInfo.mode === mode && root.__layoutInfo.order === requestedLayoutInfo.order) {
                changedExceptGeometry = false
                console.info("[FULLSCREEN:Container][" + root.objectName + "][" + requestedLayoutInfo.order + "] layout info except geometry is not changed")
            } else {
                changedExceptGeometry = true
                console.info("[FULLSCREEN:Container][" + root.objectName + "][" + requestedLayoutInfo.order + "] layout info except geometry is changed")
            }
        }

        root.__layoutInfo.appId = requestedLayoutInfo.appId
        root.__layoutInfo.mode = mode
        root.__layoutInfo.usageType = usageType
        root.__layoutInfo.order = requestedLayoutInfo.order
        root.__layoutInfo.isPipSub = isPipSub

        console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] fullscreenCover.visible " + fullscreenCover.visible)

        if (fullscreenCover.visible) {
            __storePendingLayoutInfo(requestedLayoutInfo.x, requestedLayoutInfo.y, requestedLayoutInfo.width, requestedLayoutInfo.height, requestedLayoutInfo.orientation, isPipSub, requestedLayoutInfo.decorationConfig, changedExceptGeometry)
            if (root.coverState === SurfaceItem.CoverStateNormal) {
                console.info("[FULLSCREEN::Container][" + root.objectName + "][" + root.__layoutInfo.order + "] set cover state to changing because store pending layout")
                __updateCoverState(SurfaceItem.CoverStateChanging)
            }
            layoutInfoUpdated()
            return
        }

        root.isGeometryChanged = false
        if (changedExceptGeometry === false) {
            if ((root.__layoutInfo.x !== requestedLayoutInfo.x) || (root.__layoutInfo.y !== requestedLayoutInfo.y) ||
                (root.__layoutInfo.width !== requestedLayoutInfo.width) || (root.__layoutInfo.height !== requestedLayoutInfo.height))
                root.isGeometryChanged = true
        }

        root.__layoutInfo.x = requestedLayoutInfo.x ? requestedLayoutInfo.x : 0
        root.__layoutInfo.y = requestedLayoutInfo.y ? requestedLayoutInfo.y : 0
        root.__layoutInfo.z = (isPipSub) ? 2 : 0
        root.__layoutInfo.width = requestedLayoutInfo.width ? requestedLayoutInfo.width : 0
        root.__layoutInfo.height = requestedLayoutInfo.height ? requestedLayoutInfo.height : 0
        root.__layoutInfo.visibleState = (root.__layoutInfo.width > 0) && (root.__layoutInfo.height > 0)
        root.__layoutInfo.multiviewOrientation = (requestedLayoutInfo.orientation !== undefined) ? requestedLayoutInfo.orientation : "landscape"
        root.__layoutInfo.decorationConfig = (requestedLayoutInfo.decorationConfig !== undefined) ? requestedLayoutInfo.decorationConfig : ({})
        console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] container layoutInfo's multiviewOrientation is  " + root.__layoutInfo.multiviewOrientation)


        __setAniDuration()
        layoutInfoUpdated()

        ssd.updateDecorationLayout(root.__layoutInfo)
        if(changedExceptGeometry){
            ssd.startAni()
        }
    }

    function setControlMode(isControlMode) {
        console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] control mode is updated to " + isControlMode + " for " + root.objectName)
        if ((root.__surfaceItem === null && isControlMode) || root.controlMode === isControlMode)
           return

        root.controlMode = isControlMode
        if (root.__layoutInfo.mode === "sxs" ||  (root.__layoutInfo.mode === "pip" && !root.__layoutInfo.isPipSub)) {
            root.z = root.controlMode ? 2 : 0
        }
    }

    function applyNewLayout() {

        console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] applyNewLayout")

        if (fullscreenCover.visible) {
            console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] Cover status. Wait to apply layout")
            return
        }

        if (__checkAnimationExceptionCase() && !root.forceAnimation) {
            __applyNewLayoutWithoutAnimation()
            root.applyLayoutDone(root)
            return
        }

        console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] previous layout info - ", root.x, root.y, root.z, root.width, root.height)
        console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] changed layout info - ", root.__layoutInfo.x, root.__layoutInfo.y, root.__layoutInfo.z, root.__layoutInfo.width, root.__layoutInfo.height)

        // Start animation at the center position of container
        if (root.visibleState === false && root.__layoutInfo.visibleState === true && isMultiViewMode())
        {
            root.x = root.__layoutInfo.x + root.__layoutInfo.width * 0.5
            root.y = root.__layoutInfo.y + root.__layoutInfo.height * 0.5
        }

        // Finish animation at the center position of container
        if (root.visibleState === true && root.__layoutInfo.visibleState === false && (root.currentMode === "pip" || root.currentMode === "sxs"))
        {
            root.__layoutInfo.x = root.x + root.width * 0.5
            root.__layoutInfo.y = root.y + root.height * 0.5
        }

        root.currentMode = root.__layoutInfo.mode
        root.currentOrder = root.__layoutInfo.order

        /*
            --- cover state ---
            Normal : show video. can call setDisplayWindow anytime
            Hidden : hide video. call setDisplayWindow 0x0
            Changing : keep current video. Do not call setDisplayWindow
            -------------------

            1. show cover UI (fullscreenCover)
            2. set cover state - changing
                -> keep current video to prevent video transient
            3. delay timer 150ms - to wait show cover
            4. (timer triggered) set cover state - hidden
                -> hide video through video window
            5. delay timer 150ms - to wait hide video
            6. (timer triggered) container animation start
            7. after animation, delay timer - to wait graphic rendering
            8. (timer triggered) reset cover state
                8-1. set cover state - changing, when pending layout is exist
                    -> keep current video(0x0)
                8-2. set cover state - normal, when other case
                    -> show video
            9. delay timer - to wait show video
                -> set cover state - chaning, if pending layout is stored while wait delay
            10. (timer triggered) hide cover UI
        */

        fullscreenCover.visible = true

        root.animationState = "running"
        __updateCoverState(SurfaceItem.CoverStateChanging)
        console.info("[FULLSCREEN:Container][" + root.__layoutInfo.order + "] start delay timer to show cover ")
        __beforeAnimation = true
        delayAnimationTimer.delayInterval = 150
        delayAnimationTimer.restart()
    }

    function order() {
        return root.__layoutInfo.order
    }

    function mode() {
        return root.__layoutInfo.mode
    }

    function usageType() {
        return root.__layoutInfo.usageType
    }

    function currentAppId() {
        return (root.__surfaceItem && root.__surfaceItem.appId) ? root.__surfaceItem.appId : ""
    }

    function isMultiViewMode() {
        return (root.__layoutInfo.mode === "pip" || root.__layoutInfo.mode === "sxs")
    }

    function isMultiViewLandscapeMode() {
        return (root.__layoutInfo.multiviewOrientation === "landscape")
    }

    function isPipSubContainer() {
        return (root.__layoutInfo.isPipSub === true)
    }

    function getSurfaceItem() {
        return root.__surfaceItem;
    }

    function setSurfaceItem(item) {

        if (root.__surfaceItem === item) return;

        __displayWindowNotified = [];
        __resetGroupedItems()

        if (root.__surfaceItem) {
            console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] surfaceItem is changed from " + root.__surfaceItem + " to " + item )
            root.__surfaceItem.parent = null
            root.__surfaceItem.fullscreen = false
            if (item === null && !root.connected) {
                console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] surfaceItem was removed from model and container will be destroyed.")
                return
            }
            root.__surfaceItem = null
        } else {
            console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] previous surfaceItem is empty");
        }

        root.__surfaceItem = item

        if (root.__surfaceItem) {
            __updateLayoutInfoBasedOnRotation()

            if (isMultiViewMode() && (usageType() === "appView") && root.__layoutInfo.isPipSub)
                root.__surfaceItem.enabled = false
        }

        if (item) {
            root.__surfaceItem.parent = surfaceItemContainer   // To clip surface item
            root.__surfaceItem.useTextureAlpha = true
        }

        __checkAndUpdateVideoDisplay()

        if (root.__surfaceItem && root.__surfaceItem.surfaceGroup) {
            __setGroupedOwnerItems(item)
        }
        __changeGroupedStatus()
        layoutInfoUpdated()
        surfaceItemChanged()

        __updateCoverState(root.coverState)
    }

    function getShowToolbarStatus() {
        return root.__showToolbarStatus
    }

    function setShowToolbarStatus(status) {
        root.__showToolbarStatus = status
    }

    function resetContainer() {
        console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] reset container");
        setSurfaceItem(null)
        resetNextLayoutInfo()
        __setAniDuration()
        setControlMode(false)
        ssd.resetDecorationLayout()
    }

    function resetDecorationFocus() {
        ssd.setVisible(false)
        ssd.setFocus(false)
    }

    function emptyNextAppId() {
        return root.__layoutInfo.appId === ""
    }

    function emptyCurrentItem() {
        if (root.__surfaceItem)
            return false

        return true
    }

    function getContainerInfo() {
        var containerInfo = {};
        containerInfo["appId"] = root.__surfaceItem ? root.__surfaceItem.appId : null
        containerInfo["nextAppId"] = root.__layoutInfo.appId
        containerInfo["mode"] = root.__layoutInfo.mode
        containerInfo["order"] = root.__layoutInfo.order
        containerInfo["active"] = root.active
        containerInfo["visible"] = root.visible
        containerInfo["surfaceItem"] = root.__surfaceItem
        containerInfo["grouped"] = root.grouped
        containerInfo["groupedItems"] = root.__groupedItems

        return containerInfo;
    }

    function getGeometryInfo() {
        var geometryInfo = {}
        geometryInfo["x"] = root.__layoutInfo.x
        geometryInfo["y"] = root.__layoutInfo.y
        geometryInfo["width"] = root.__layoutInfo.width
        geometryInfo["height"] = root.__layoutInfo.height

        return geometryInfo
    }

    function getToolbarPosition() {
        return ssd.toolbarPosition
    }

    function setFocus(bFocus) {
        console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] setFocus = " + bFocus)

        if (bFocus) {
            root.focus = true
            root.needItemFocus = true
            setItemFocus(true)
        } else {
            root.focus = false
            root.needItemFocus = false
            setItemFocus(false)
        }
    }

    function hasActiveGroupedItem() {
        var retValue = false
        if (groupModelLoader.item)
            retValue = groupModelLoader.item.hasActiveFocus();
        return retValue;
    }

    function __setAniDuration() {

        if (root.width === root.__layoutInfo.width && root.height === root.__layoutInfo.height)
        {
            containerAnimator.aniDuration = 400
        }
        else if ((Math.abs(root.x-root.__layoutInfo.x) > root.parent.width*0.3)
                    || (Math.abs(root.y-root.__layoutInfo.y) > root.parent.height*0.3)
                        || (Math.abs(root.width-root.__layoutInfo.width) > root.parent.width*0.3)
                            || (Math.abs(root.height-root.__layoutInfo.height) > root.parent.height*0.3))
        {
           containerAnimator.aniDuration = 600
        }
        else
        {
            containerAnimator.aniDuration = 300
        }
    }

    function __setPendingLayoutInfo() {

        console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "]")

        var needApplyLayout = false
        if (root.__pendingLayoutInfo.isPending) {
            if (root.__pendingLayoutInfo.needReset) {
                resetNextLayoutInfo()
                ssd.resetDecorationLayout()
            } else {
                var layoutInfo = {
                    "appId": root.__layoutInfo.appId,
                    "order": root.__layoutInfo.order,
                    "x": root.__pendingLayoutInfo.x,
                    "y": root.__pendingLayoutInfo.y,
                    "width": root.__pendingLayoutInfo.width,
                    "height": root.__pendingLayoutInfo.height,
                    "orientation": root.__pendingLayoutInfo.multiviewOrientation,
                    "decorationConfig": root.__pendingLayoutInfo.decorationConfig
                }
                setNextLayout(root.__layoutInfo.mode, root.__layoutInfo.usageType, layoutInfo, root.__pendingLayoutInfo.isPipSub, root.__pendingLayoutInfo.changedExceptGeometry)
            }
            needApplyLayout = true
        } else {
            console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] There is no pending info")
        }
        root.__pendingLayoutInfo.reset()

        if (needApplyLayout)
            applyNewLayout()
    }

    function __storePendingLayoutInfo(x, y, w, h, multiviewOrientation, isPipSub, decorationConfig, changedExceptGeometry) {

        console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] store pending info")

        root.__pendingLayoutInfo.isPending = true
        root.__pendingLayoutInfo.needReset = false
        root.__pendingLayoutInfo.x = x
        root.__pendingLayoutInfo.y = y
        root.__pendingLayoutInfo.width = w
        root.__pendingLayoutInfo.height = h
        root.__pendingLayoutInfo.multiviewOrientation = (multiviewOrientation !== undefined) ? multiviewOrientation : "landscape"
        root.__pendingLayoutInfo.isPipSub = isPipSub
        root.__pendingLayoutInfo.decorationConfig = (decorationConfig !== undefined) ? decorationConfig : ({})
        root.__pendingLayoutInfo.changedExceptGeometry = changedExceptGeometry
    }

    function __applyNewLayoutWithoutAnimation() {

        console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] apply new layout without animation")

        root.rotation = root.__layoutInfo.rotation
        root.x = root.__layoutInfo.x
        root.y = root.__layoutInfo.y
        root.z = root.__layoutInfo.z
        root.height = root.__layoutInfo.height
        root.width = root.__layoutInfo.width

        root.currentMode = root.__layoutInfo.mode
        root.currentOrder = root.__layoutInfo.order

        __fitSurfaceItemToParent()
    }

    function __checkAnimationExceptionCase() {

        if (!ssd.__config.animation)
            return true

        if (root.currentMode === "" && root.__layoutInfo.mode === "")
            return true

        if (root.x ===  root.__layoutInfo.x
            && root.y === root.__layoutInfo.y
                && root.width === root.__layoutInfo.width
                    && root.height === root.__layoutInfo.height)
                    {
                        console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] geometry is not changed")
                        return true
                    }

        if (root.rotation !== root.__layoutInfo.rotation ||
            (root.__layoutInfo.rotation == 90 || root.__layoutInfo.rotation == 270)) {
            console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] rotation is changed. Skip the animation")
            return true
        }

        /*Note : No animation case
            "" <-> pip + main <-> normal
        */
        if (root.currentMode !== root.__layoutInfo.mode && root.visibleState !== root.__layoutInfo.visibleState)
        {
            if ((root.width === root.parent.width && root.height === root.parent.height && root.__layoutInfo.visibleState === false)
                || (root.__layoutInfo.width === root.parent.width && root.__layoutInfo.height === root.parent.height && root.visibleState === false))
                {
                    console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] fullscreen app switch case")
                    return true
                }
        }

        if (root.currentMode === "sxs" && isMultiViewMode() === false && emptyNextAppId()) {
            return true
        }

        if (nextAppId().indexOf("empty") !== -1) {
            console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] Cover app to be changed or closed.")
            return true
        }

        return false
    }

    function __updateCoverState(state) {

        console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] update cover state = " + state)
        if (root.__surfaceItem)
            root.__surfaceItem.coverState = state
        root.coverState = state

        console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] update cover state of groupModelLoader = " + groupModelLoader.item)
        if (groupModelLoader.item)
            groupModelLoader.item.updateCoverState(state)
    }

    function __setGroupedOwnerItems(item) {
        if (root.__surfaceItem && root.__surfaceItem.surfaceGroup && root.__surfaceItem == item) {
            root.__groupedItems = [item]
            root.__loadGroupModel()
        }
    }

    function __resetGroupedItems() {
        root.__groupedItems = []
        root.__groupLowerChildren = [];
        root.__groupUpperChildren = [];

        groupModelLoader.setSource("");
    }

    function __changeGroupedStatus() {
        root.grouped = (root.__surfaceItem && root.__surfaceItem.surfaceGroup && root.__groupedItems.length > 0) ? true : false
        root.groupedStatusUpdated()
    }

    function __updateLayoutInfoBasedOnRotation() {
        if (root.__surfaceItem == null) {
            console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] surfaceItem is null")
            return
        }

        console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "][updateLayoutInfoBasedOnRotation-START] appId:" + root.__surfaceItem.appId + " layoutInfo (rotation:" + root.__layoutInfo.rotation +
                     " width:" + root.__layoutInfo.width + " height:" + root.__layoutInfo.height + " x:" + root.__layoutInfo.x + " y:" + root.__layoutInfo.y + ")")

        switch (root.__surfaceItem.orientation) {
            case 1:  root.__layoutInfo.rotation = 270;  break;
            case 2:  root.__layoutInfo.rotation = 0;   break;
            case 4:  root.__layoutInfo.rotation = 90; break;
            case 8:  root.__layoutInfo.rotation = 180; break;
            default: root.__layoutInfo.rotation = 0;   break;
        }

        if (root.__layoutInfo.rotation % 180) {
            // This case is for portrait.
            root.__layoutInfo.width = root.parent.height // root.parent is fullscreenView
            root.__layoutInfo.height = root.parent.width

            root.__layoutInfo.x = Utils.center(root.parent.width, root.__layoutInfo.width)
            root.__layoutInfo.y = Utils.center(root.parent.height, root.__layoutInfo.height)
        } else {
            // else is for landscape. Layout for landscape shoud consider the multiview settings that is already set in setLayout() func.
            if (!isMultiViewMode()) {
                root.__layoutInfo.width = root.parent.width // root.parent is fullscreenView
                root.__layoutInfo.height = root.parent.height

                root.__layoutInfo.x = Utils.center(root.parent.width, root.__layoutInfo.width)
                root.__layoutInfo.y = Utils.center(root.parent.height, root.__layoutInfo.height)
            }
        }

        console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "][updateLayoutInfoBasedOnRotation-END] appId:" + root.__surfaceItem.appId + " layoutInfo (rotation:" + root.__layoutInfo.rotation +
                     " width:" + root.__layoutInfo.width + " height:" + root.__layoutInfo.height + " x:" + root.__layoutInfo.x + " y:" + root.__layoutInfo.y + ")")
    }

    onGroupUpdated: {
        var isChanged = false;
        if ((change === "both" || change === "lower") && __isChildItemsUpdated(groupLowerChildren, root.__groupLowerChildren)) {
            root.__groupLowerChildren = groupLowerChildren;
            isChanged = true;
        }

        if ((change === "both" || change === "upper") && __isChildItemsUpdated(groupUpperChildren, root.__groupUpperChildren)) {
            root.__groupUpperChildren = groupUpperChildren;
            isChanged = true;
        }

        if (isChanged) {
            if (root.grouped && root.__surfaceItem) {
                root.__groupedItems = root.__groupLowerChildren.concat(Array(root.__surfaceItem), root.__groupUpperChildren);
                console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] surfaceItem's group is updated, surfaceItem = " + root.__surfaceItem + ", change = " + change + ", groupedItem = " + root.__groupedItems);
            }
        }
    }

    onWindowPositionChanged: {
        __checkAndUpdateVideoDisplay();
    }

    onActiveChanged: {
        console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] appId:" + (root.__surfaceItem ? root.__surfaceItem.appId : "") + ", activeFocus:" + root.activeFocus +
                     ", surfaceItem.activeFocus:" + root.active + ", hasActiveGroupedItem:" + root.hasActiveGroupedItem());

        layoutInfoUpdated();
    }

    onActiveFocusChanged: {
        console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] appId:" + (root.__surfaceItem ? root.__surfaceItem.appId : "") + ", activeFocus:" + root.activeFocus +
                     ", surfaceItem.activeFocus:" + root.active + ", hasActiveGroupedItem:" + root.hasActiveGroupedItem());
    }

    onHasFocusedSurfaceItemChanged: {
        console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] appId:" + (root.__surfaceItem ? root.__surfaceItem.appId : "") + ", activeFocus:" + root.activeFocus +
                     ", surfaceItem.activeFocus:" + root.active + ", hasActiveGroupedItem:" + root.hasActiveGroupedItem());
        focusedSurfaceItem(root.__layoutInfo.order, hasFocusedSurfaceItem); // sends a signal whenever a surfaceitem of focus changes
    }

    onDragCoverChanged: {
        // Prevent mismatch of video position when dragging sub app in pip mode
        if (root.dragCover)
            __updateCoverState(SurfaceItem.CoverStateHidden)
        else
            __updateCoverState(SurfaceItem.CoverStateNormal)
    }

    onMultiviewControllerServiceChanged: {
        ssd.ssdService = root.multiviewControllerService
    }

    function __checkAndUpdateVideoDisplay(){
        var diff = false;
        var params;

        if (windowPosition.length === 0 || __surfaceItemType !== "_WEBOS_WINDOW_TYPE_CARD") {
            __displayWindowNotified = [];
            return;
        }

        console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] Update window position");
        if (windowPosition.length != __displayWindowNotified.length) {
            diff = true;
        } else {
            for (var i = 0; i < windowPosition.length; i++) {
                if (windowPosition[i].id != __displayWindowNotified[i].context
                    || windowPosition[i].punchX != __displayWindowNotified[i].displayOutput.x
                        || windowPosition[i].punchY != __displayWindowNotified[i].displayOutput.y
                            || windowPosition[i].punchW != __displayWindowNotified[i].displayOutput.width
                                || windowPosition[i].punchH != __displayWindowNotified[i].displayOutput.height)
                    {
                        diff = true;
                        break;
                    } else {
                        console.log("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] windowPosition info is same as notified one");
                    }
            }
        }

        if (diff)
            __setVideoDisplayWindow();
    }

    function __setVideoDisplayWindow() {
        var region, params;
        __displayWindowNotified = [];
        for (var i = 0; i < windowPosition.length; i++) {
            region = windowPosition[i];
            if (region.id === "") {
                console.log("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] Pipeline id is empty. Do not call setDisplayWindow");
                continue;
            }
            params = {
                "displayOutput": {
                    "x": region.punchX,
                    "y": region.punchY,
                    "width": region.punchW,
                    "height": region.punchH
                },
                "context": region.id,
                "fullScreen": true
            };
            __displayWindowNotified.push(params);
            console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] Calling setDisplayWindow:", JSON.stringify(params));
            LS.adhoc.call("luna://com.webos.service.videooutput", "/display/setDisplayWindow", JSON.stringify(params));
        }
    }

    function __isChildItemsUpdated(childItems, targetChildItems) {
        //To block redundant getForegroundAppInfo publishing, check real change of child items is occurred or not.
        var isChildItemsSame = (targetChildItems.length == childItems.length) && targetChildItems.every(function(element, index) {
            return element === childItems[index];
        });
        return (isChildItemsSame) ? false : true;
    }

    function __loadGroupModel() {
        if (!root.__surfaceItem) {
            console.warn("Surface item is empty. Group model can't be loaded.");
            return;
        }

        console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] __loadGroupModel. groupOwner = " + root.__surfaceItem + ", groupOwnerParent = " + root);
        groupModelLoader.setSource("../../models/StarfishGroupModel.qml", { objectName: "fullscreenGroupModel", groupOwner: root.__surfaceItem, groupOwnerParent: root });
    }

    function __fitSurfaceItemToParent() {

        if (containerAnimator.running) {
            console.log("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] container animator is running")
            return
        }

        if (__surfaceItem) {
            console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] [FitSurfaceItem-START] x = " + root.x + " , y= " + root.y + ", width = " + root.width + " , height = " + root.height);
            console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] surface item appId = " + __surfaceItem.appId+ ", width = " + __surfaceItem.width + ", height = " + __surfaceItem.height + " , previous scale factor = " + __surfaceItemScale)

            if (root.width === 0 || root.heigth === 0 || __surfaceItem.width <= 0 || __surfaceItem.height <= 0) {
                __surfaceItem.x = 0
                __surfaceItem.y = 0
                __surfaceItem.scale = 0
            } else {
                __surfaceItem.x = root.width / 2 -  __surfaceItem.width / 2;
                __surfaceItem.y = root.height / 2 - __surfaceItem.height / 2;

                if (root.__layoutInfo.multiviewOrientation === "landscape") {
                    __surfaceItem.scale = Math.min(root.width / __surfaceItem.width, root.height / __surfaceItem.height)
                    __surfaceItem.activeRegion = Qt.rect(0,0,0,0)
                } else {
                    __surfaceItem.scale = root.height / __surfaceItem.height
                    var activeWidth = root.width * __surfaceItem.height / root.height
                    var activeX = (__surfaceItem.width - activeWidth) * 0.5
                    var activeRegion =  Qt.rect(activeX, 0, activeWidth, __surfaceItem.height)
                    console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] portrait active region = " + activeRegion)
                    __surfaceItem.activeRegion = activeRegion
                }
            }

            if (root.__layoutInfo.isPipSub) {
                var surfaceToContainer = __surfaceItem.mapToItem(root, 0, 0, __surfaceItem.width, __surfaceItem.height)

                // To fix error when calculate activeRegion in LSM, add margin 1 pixel to all directions.
                var tempMargin = (root.__layoutInfo.multiviewOrientation === "landscape" ? 0 : 1)

                bgBlack.anchors.leftMargin = Math.max(surfaceToContainer.x, 0) + tempMargin
                bgBlack.anchors.topMargin = Math.max(surfaceToContainer.y, 0) + tempMargin
                bgBlack.anchors.rightMargin = Math.max(root.width - surfaceToContainer.right, 0) + tempMargin
                bgBlack.anchors.bottomMargin = Math.max(root.height - surfaceToContainer.bottom, 0) + tempMargin
            } else {
                bgBlack.anchors.leftMargin = 0
                bgBlack.anchors.topMargin = 0
                bgBlack.anchors.rightMargin = 0
                bgBlack.anchors.bottomMargin = 0
            }
            Utils.pmLog.info("SVU_LSM_BG_BLACK", {}, "[FULLSCREEN] global positions. surfaceitem : " + __surfaceItem.mapToItem(null, 0, 0, __surfaceItem.width, __surfaceItem.height) + ", bgBlack : " + bgBlack.mapToItem(null, 0, 0, bgBlack.width, bgBlack.height));

            if (__surfaceItemScale !== __surfaceItem.scale) {
                console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] surface item scale is changed. scale = " + __surfaceItem.scale)
                __surfaceItem.scaleChanged()
                __surfaceItemScale = __surfaceItem.scale
            }

            if (__surfaceItem.pipSub !== root.__layoutInfo.isPipSub) {
                console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] surface item pipSub is changed. pipSub = " + root.__layoutInfo.isPipSub)
                __surfaceItem.pipSub = root.__layoutInfo.isPipSub;
            }

            console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] [FitSurfaceItem-END] update surfaceitem's position and scale. x = " + __surfaceItem.x +",  y = " + __surfaceItem.y + " , scale = " + __surfaceItem.scale)
        }
    }

    function setItemFocus(focus) {
        if (root.__surfaceItem) {
            console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] setItemFocus = " + focus + " for item = " + root.__surfaceItem.appId)
        }

        if (focus) {
            if (groupModelLoader.item)
                groupModelLoader.item.updateGroup();
            else if (root.__surfaceItem)
                root.__surfaceItem.takeFocus();
            compositor.updateCursorFocus();
            compositor.updateCursorSettings(cursorFps, __restoreCursorPositionSetting, cursorDisplay);
            if(cloudgameActivefromWinProp || cloudgameActivefromAppInfo) {
                compositor.updateCloudgameActiveState(true);
            } else {
                compositor.updateCloudgameActiveState(false);
            }
        } else {
            if (groupModelLoader.item)
                groupModelLoader.item.resetFocus();
            else if (root.__surfaceItem)
                root.__surfaceItem.focus = focus;
        }
    }

    function setHiddenContainer() {
        console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] " + "set hidden container")
        root.directDestroy = true
        root.__updateCoverState(SurfaceItem.CoverStateHidden)
        root.visible = false
    }

    function unsetHiddenContainer() {
        console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] " + "unset hidden container")
        root.directDestroy = false
        root.__updateCoverState(SurfaceItem.CoverStateNormal)
        root.visible = true
    }

    onCursorFpsChanged: {
        console.info("[FULLSCREEN] onCursorFpsChanged FPS : " + cursorFps + "restoreCursorPos : " + __restoreCursorPositionSetting + "CursorDisplay : " + cursorDisplay);
        compositor.updateCursorSettings(cursorFps, __restoreCursorPositionSetting, cursorDisplay);
    }

    onCursorDisplayChanged: {
        console.info("[FULLSCREEN] onCursorDisplayChanged FPS : " + cursorFps + "restoreCursorPos : " + __restoreCursorPositionSetting + "CursorDisplay : " + cursorDisplay);
        compositor.updateCursorSettings(cursorFps, __restoreCursorPositionSetting, cursorDisplay);
    }

    onCloudgameActivefromWinPropChanged: {
        console.info("[FULLSCREEN:onCloudgameActiveChanged] cloudgame_active : "+ cloudgameActivefromWinProp);
        compositor.updateCloudgameActiveState(cloudgameActivefromWinProp);
    }

    onHeightChanged: {
        //console.info("[FULLSCREEN] "+ root.objectName + " x = " + root.x + " y = " + root.y + " width = " + root.width + " height = " + root.height  + " rotation: " +root.rotation)
        __fitSurfaceItemToParent()
    }

    onControlModeChanged: {
        if (root.controlMode)
            controlModeGuideTimer.restart()
    }

    onAnimationStateChanged: {
        if (isMultiViewMode()) {
            views.fullscreen.multiViewLayoutAnimationStateChanged()
        }
    }

    onCurrentModeChanged: {
        ssd.inputModeRequested = false // if mode is changed, inputmode should be released
    }

    onVisibleChanged: console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] visible: " +root.visible)

    function getLayoutAnimationState(){
        var state = new Object() ;
        state.order = root.__layoutInfo.order ;
        state.state = animationState ;
        return state
    }

    Connections {
        target: views.fullscreen
        onUserInputOnControlMode: {
            if (!controlModeGuideTimer.running)
                controlModeGuideTimer.restart()
        }
        onFocusedSurfaceItemChanged: {
            if(!focus || !target.isMultiViewMode || (root.objectName === "baseContainer" && !target.baseContainerInMultiview)) return

            console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] focused item's order:" + order + " order " + root.__layoutInfo.order + "/"+ order )
            if(root.__layoutInfo.order != order) {
                ssd.inputModeRequested = false  // release inputmode
            }else { //focused app
                target.__setCurrentItem(getSurfaceItem())
            }
        }

        onRequestShowVolumeUI: {
            if(!target.isMultiViewMode || (root.objectName === "baseContainer" && !target.baseContainerInMultiview)) return
            ssd.showVolumeUI(true)
        }

        onRequestShowIndexForApps: {
            if(!target.isMultiViewMode || (root.objectName === "baseContainer" && !target.baseContainerInMultiview)) return
            ssd.showIndexForApps(visible)
       }

        onShowToolbar: {
            if(!target.isMultiViewMode ||
              (root.objectName === "baseContainer" && !target.baseContainerInMultiview) ||
              (root.__layoutInfo.usageType === "appView") ||
               target.isControlMode() ||
               delayAnimationTimer.running ||
               containerAnimator.running ) {
                return
            }

            console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] order:", order, "----------------------------")
            if(root.__layoutInfo.order != order) {
                root.setShowToolbarStatus(false)
                root.z = root.__layoutInfo.z
                ssd.expireTimer.stop()
                if(!target.isInputMode()) {
                    ssd.setFocus(false)
                }
                ssd.state = "active_init"
                ssd.setVisible(false)
            } else{
                root.setShowToolbarStatus(true)
                root.z = root.__layoutInfo.z + 1
                if(!target.isInputMode()){
                    ssd.setFocus(true)
                }
                ssd.state = (ssd.state !== "active_inputmode" ? "active_focused" : ssd.state)
                ssd.setVisible(true)
                ssd.requestFullScreenTimerRestart()
            }
            console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] order:", order, "z", root.z, "/", root.__layoutInfo.z)
        }
    }

    property Timer controlModeGuideExpireTimer: Timer {
        id: controlModeGuideTimer
        running: false
        repeat: false
        interval: Settings.local.multiviewControlMode.timeout
    }
    property Timer appViewClosingTimer: Timer {
        id: appViewClosingTimer
        running: false
        repeat: false
        interval: 300
        onTriggered: {
            console.info("[FULLSCREEN:Container][" + root.__layoutInfo.order + "] appView closing timer is done")
            __updateCoverState(SurfaceItem.CoverStateNormal)
        }
    }

    function startAppViewClosingCover() {
        console.info("[FULLSCREEN:Container][" + root.__layoutInfo.order + "] appView closing timer start")
        __updateCoverState(SurfaceItem.CoverStateHidden)
        appViewClosingTimer.restart()
    }

    property Timer delayAnimationTimer: Timer {
        id: delayAnimationTimer
        property int delayInterval: 50
        running: false
        interval: delayInterval
        onTriggered: {
            console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] delay animation timer is triggered ")

            if (root.coverState === SurfaceItem.CoverStateNormal || root.coverState === SurfaceItem.CoverStateChanging) {
                if (__beforeAnimation) {
                    console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] start delay timer to hide video")
                    __updateCoverState(SurfaceItem.CoverStateHidden)
                    delayAnimationTimer.delayInterval = 150
                    delayAnimationTimer.restart()
                } else {
                    __fitSurfaceItemToParent()
                    console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] hide cover UI on container")
                    fullscreenCover.visible = false
                    __beforeAnimation = true
                    root.animationState = "ready"

                    if (root.__layoutInfo.visibleState === false) {
                        root.x = 0
                        root.y = 0
                        root.__layoutInfo.x = 0
                        root.__layoutInfo.y = 0
                    }
                    __setPendingLayoutInfo()
                    if (fullscreenCover.visible === false)
                        __updateCoverState(SurfaceItem.CoverStateNormal)

                    root.applyLayoutDone(root)
                }

            } else if (root.coverState === SurfaceItem.CoverStateHidden) {
                if (__beforeAnimation) {
                    console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] start animation")
                    containerAnimator.restart()
                } else {
                    if (root.__pendingLayoutInfo.isPending) {
                        __updateCoverState(SurfaceItem.CoverStateChanging)
                    } else {
                        __updateCoverState(SurfaceItem.CoverStateNormal)
                    }

                    console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] start delay timer to show video cover state = " + coverState)

                    delayAnimationTimer.delayInterval = 300
                    delayAnimationTimer.restart()
                }
            }
        }
    }

    Connections {
        target: containerAnimator
        onRunningChanged: {
            console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] containerAnimator running = " + containerAnimator.running)
            if (!containerAnimator.running) {
                __beforeAnimation = false
                console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] Container animation is finished")
                __fitSurfaceItemToParent()

                console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] after animation, start delay timer to wait graphic rendering ")
                delayAnimationTimer.delayInterval = 50
                delayAnimationTimer.restart()
            }
        }
    }

    ParallelAnimation {
        id : containerAnimator
        property int aniDuration: 500
        PropertyAnimation  {target: root; property: "x"; to: __layoutInfo.x; easing.type: Easing.Linear; duration: containerAnimator.aniDuration}
        PropertyAnimation  {target: root; property: "y"; to: __layoutInfo.y; easing.type: Easing.Linear;  duration: containerAnimator.aniDuration}
        PropertyAnimation  {target: root; property: "z"; to: __layoutInfo.z; easing.type: Easing.Linear; duration: containerAnimator.aniDuration}
        PropertyAnimation  {target: root; property: "width"; to: __layoutInfo.width; easing.type: Easing.Linear; duration: containerAnimator.aniDuration}
        PropertyAnimation  {target: root; property: "height"; to: __layoutInfo.height; easing.type: Easing.Linear; duration: containerAnimator.aniDuration}
   }

    Connections {
        target: __surfaceItem
        onStateChanged: {
            console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] surfaceItem state is changed to "  + root.__surfaceItem.state);

            if (groupModelLoader.item)
                groupModelLoader.item.updateGroupState(__surfaceItem.state);

            root.appStateChanged()
        }

        onSurfaceGroupChanged: {
            if (__surfaceItem)
                console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] surfaceItem's surfaceGroup changed to = " + root.__surfaceItem.surfaceGroup);

            __resetGroupedItems()
            if (__surfaceItem && __surfaceItem.surfaceGroup)
                __setGroupedOwnerItems(__surfaceItem)
            __changeGroupedStatus()
        }

        // There is a case that surface item's geometry is set after surface item is mapped.
        // If handling both onWidthChanged and onHeightChanged, fitSurfaceItemToParent is called twice.
        // Also, width and height are changed at the same time on fullscreen case. So, handle only one signal.
        onWidthChanged: {
            console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] surface item's width is updated. Check surface item's scale.")
            __fitSurfaceItemToParent()
        }

        onOrientationChanged: {
            console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] surfaceitem's orientation is changed. orientation = " +root.__surfaceItem.orientation);
            if (root.__surfaceItem && root.__surfaceItem.orientation >= 0) {
                __updateLayoutInfoBasedOnRotation();
                applyNewLayout()
            }
        }

        onEnabledChanged : console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] surfaceitem's enabled is changed. enabled = " +root.__surfaceItem.enabled);
    }

    Loader {
        id: groupModelLoader
        asynchronous: true
        onLoaded: {
            console.info("[FULLSCREEN:Container][" + root.objectName + "][" + root.__layoutInfo.order + "] Group model is loaded. update cover state to " + root.coverState )
            groupModelLoader.item.updateCoverState(root.coverState)
        }
    }

    onLayoutInfoUpdated: {
        var region = Qt.rect(views.starfishViewAdjustments.mx, views.starfishViewAdjustments.my, views.starfishViewAdjustments.mw, views.starfishViewAdjustments.mh);
        var list = StarfishUtils.foregroundList(views.children)
        for (var i = 0; i < list.length; i++) {
            var item = list[i]
            item.zoomValue = views.starfishViewAdjustments.zoomValue
            item.zoomRegion = region
        }
    }

    function makeScreenRequest()
    {
        if( views.starfishViewAdjustments.zoomStatus )
        {
            var screenRect = Qt.rect(
                ( ( compositorWindow.outputGeometry.x - views.starfishViewAdjustments.mx ) * views.starfishViewAdjustments.zoomValue ) * compositorWindow.screenRatio,
                ( ( compositorWindow.outputGeometry.y - views.starfishViewAdjustments.my ) * views.starfishViewAdjustments.zoomValue ) * compositorWindow.screenRatio,
                ( compositorWindow.outputGeometry.width * views.starfishViewAdjustments.zoomValue ) * compositorWindow.screenRatio,
                ( compositorWindow.outputGeometry.height * views.starfishViewAdjustments.zoomValue ) * compositorWindow.screenRatio
            );

            videooutputdCommunicator.setVideoDisplayScreenRequested(
                views.starfishViewAdjustments.zoomStatus,
                views.starfishViewAdjustments.zoomStatus,
                screenRect
            );
        }
        else
        {
            var screenRect = Qt.rect(
                compositorWindow.outputGeometry.x * compositorWindow.screenRatio,
                compositorWindow.outputGeometry.y * compositorWindow.screenRatio,
                compositorWindow.outputGeometry.width * compositorWindow.screenRatio,
                compositorWindow.outputGeometry.height * compositorWindow.screenRatio
            );

            videooutputdCommunicator.setVideoDisplayScreenRequested(
                views.starfishViewAdjustments.zoomStatus,
                views.starfishViewAdjustments.zoomStatus,
                screenRect
            );
        }
    }

    function updateRegion()
    {
        var region = Qt.rect(views.starfishViewAdjustments.mx, views.starfishViewAdjustments.my, views.starfishViewAdjustments.mw, views.starfishViewAdjustments.mh);
        var list = StarfishUtils.foregroundList(views.children)
        for (var i = 0; i < list.length; i++) {
            var item = list[i]
            item.zoomValue = views.starfishViewAdjustments.zoomValue
            item.zoomRegion = region
        }
        if(views.starfishViewAdjustments.zoomStatus)
            compositor.updateZoomInfo(region, views.starfishViewAdjustments.zoomValue);
        else
            compositor.updateZoomInfo(region, 1);

        makeScreenRequest();
    }

    Connections {
        target: views.starfishViewAdjustments

        onMxChanged: {
            if(!views.starfishViewAdjustments.aniRunning)
            {
                if(views.starfishViewAdjustments.mx > (views.starfishViewAdjustments.windowWidth - views.starfishViewAdjustments.mw))
                {
                    views.starfishViewAdjustments.mx = (views.starfishViewAdjustments.windowWidth - views.starfishViewAdjustments.mw)
                    updateRegion()
                }
                else
                {
                    updateRegion()
                }
            }
        }
        onMyChanged: {
            if(!views.starfishViewAdjustments.aniRunning)
            {
                if(views.starfishViewAdjustments.my > (views.starfishViewAdjustments.windowHeight - views.starfishViewAdjustments.mh))
                {
                    views.starfishViewAdjustments.my = (views.starfishViewAdjustments.windowHeight - views.starfishViewAdjustments.mh)
                    updateRegion()
                }
                else
                {
                    updateRegion()
                }
            }
        }
        onMwChanged: {
            updateRegion()
        }
    }
}
