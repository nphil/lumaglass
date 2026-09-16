import QtQuick 2.4
import WebOSCompositorBase 1.0
import WebOSServices 1.0

// Status bar: a 60px glass pill (padding 0 10 0 6, 6px between buttons) with items built from
// layout.statusBar.left/right through a small type registry. Unknown types render a generic
// glyph so a bad layout entry never breaks the bar. "notifications" opens a glass popover
// under its button; "settings" and "search" launch their apps.
Item {
    id: bar

    property var theme: ({})
    property var mat: ({ ink: "#F2EFF6", ink2: "#A8F2EFF6", glass: "#66120E1A", glassEdge: "#21FFFFFF" })
    property bool isLight: false
    property var items: []          // merged left + right, in visual order
    property int leftCount: 1
    property bool focusedLayer: false
    property int focusedIndex: 0
    property Item backdrop: null
    property int cardMs: 180
    property int cardEasing: Easing.OutCubic
    property int layerMs: 220
    property string profileName: "Nate"

    signal requestOpenPopover(int index)
    signal requestClosePopover()
    signal hoverFocus(int index)

    function activate(index) {
        var type = items[index] ? items[index].type : ""
        if (type === "notifications") { bar.requestOpenPopover(index); return }
        if (type === "settings") LS.adhoc.call("luna://com.webos.applicationManager", "/launch", JSON.stringify({ id: "com.palm.app.settings" }))
        else if (type === "search") LS.adhoc.call("luna://com.webos.applicationManager", "/launch", JSON.stringify({ id: "com.webos.app.voice" }))
    }

    function itemAt(index) {
        return index < leftCount ? leftRepeater.itemAt(index) : rightRepeater.itemAt(index - leftCount)
    }
    function focusedGlobalX() {
        var it = itemAt(focusedIndex)
        return it ? bar.x + it.parent.x + it.x + 24 : bar.x + bar.width / 2
    }

    Glass {
        mat: bar.mat
        isLight: bar.isLight
        cardRadius: bar.height / 2
        focusMix: 0
        screenX: bar.x; screenY: bar.y; screenW: bar.width; screenH: bar.height
        backdrop: bar.backdrop
    }

    Row {
        id: leftRow
        x: 6; y: 6
        spacing: 6
        Repeater {
            id: leftRepeater
            model: bar.items.slice(0, bar.leftCount)
            delegate: StatusItem {
                kind: modelData.type
                label: modelData.type === "profile" ? bar.profileName : ""
                badge: modelData.type === "notifications" ? notifSvc.badgeCount : 0
                mat: bar.mat
                isLight: bar.isLight
                iconSource: modelData.icon ? modelData.icon : ""
                focused: bar.focusedLayer && bar.focusedIndex === index
                backdrop: bar.backdrop
                screenX: bar.x + leftRow.x + x; screenY: bar.y + leftRow.y
                onActivated: bar.activate(index)
                onHoverFocus: bar.hoverFocus(index)
            }
        }
    }

    Row {
        id: rightRow
        x: bar.width - 10 - width; y: 6
        spacing: 6
        Repeater {
            id: rightRepeater
            model: bar.items.slice(bar.leftCount)
            delegate: StatusItem {
                kind: modelData.type
                badge: modelData.type === "notifications" ? notifSvc.badgeCount : 0
                mat: bar.mat
                isLight: bar.isLight
                iconSource: modelData.icon ? modelData.icon : ""
                focused: bar.focusedLayer && bar.focusedIndex === (index + bar.leftCount)
                backdrop: bar.backdrop
                screenX: bar.x + rightRow.x + x; screenY: bar.y + rightRow.y
                onActivated: bar.activate(index + bar.leftCount)
                onHoverFocus: bar.hoverFocus(index + bar.leftCount)
            }
        }
    }

    // Toasts are subscribe-only on this firmware (no backlog), so the badge counts what has
    // arrived since Home was drawn.
    Service {
        id: notifSvc
        appId: "org.nphil.lumaglass"
        property var recent: []
        property int badgeCount: recent.length
        onResponse: {
            try {
                var msg = JSON.parse(payload)
                if (msg && msg.message) recent = [{ text: msg.message, sourceId: msg.sourceId || "" }].concat(recent).slice(0, 5)
            } catch (e) {}
        }
        Component.onCompleted: call("luna://com.webos.notification", "/getToastNotification", JSON.stringify({ subscribe: true }))
    }

    property bool popoverOpen: false
    onRequestOpenPopover: popoverOpen = true
    onRequestClosePopover: popoverOpen = false

    Item {
        id: popover
        width: 380
        height: Math.max(120, list.implicitHeight + 40)
        y: bar.height + 8 + (bar.popoverOpen ? 0 : -8)
        x: {
            var it = bar.itemAt(bar.focusedIndex)
            var cx = it ? it.parent.x + it.x + 24 : bar.width / 2
            return Math.round(Math.min(bar.width - width, Math.max(0, cx - width / 2)))
        }
        opacity: bar.popoverOpen ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: bar.layerMs; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: bar.layerMs; easing.type: Easing.OutCubic } }
        Glass {
            mat: bar.mat
            isLight: bar.isLight
            cardRadius: 18
            focusMix: 0
            screenX: bar.x + popover.x; screenY: bar.y + popover.y; screenW: popover.width; screenH: popover.height
            backdrop: bar.backdrop
        }
        Column {
            id: list
            x: 20; y: 20
            width: parent.width - 40
            spacing: 12
            Text {
                text: "Notifications"
                color: bar.mat.ink
                font.family: "Manrope"; font.weight: Font.DemiBold; font.pixelSize: 22
                renderType: Text.NativeRendering
            }
            Text {
                visible: notifSvc.recent.length === 0
                text: "No notifications"
                color: bar.mat.ink2
                font.family: "Manrope"; font.weight: Font.Medium; font.pixelSize: 20
                renderType: Text.NativeRendering
            }
            Repeater {
                model: notifSvc.recent
                delegate: Text {
                    width: list.width
                    text: modelData.text
                    color: bar.mat.ink
                    wrapMode: Text.WordWrap
                    font.family: "Manrope"; font.weight: Font.Medium; font.pixelSize: 20
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}
