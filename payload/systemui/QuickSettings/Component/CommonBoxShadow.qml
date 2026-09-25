// Drop-in replacement for LG's Component/CommonBoxShadow.qml.
//
// The stock file loads a QtGraphicalEffects DropShadow, which renders its
// source item into an offscreen texture and Gaussian-blurs it in two passes
// every time that item repaints. Quick Settings puts one behind every button,
// slider and popup, and the call sites ask for large kernels - ImageButton
// uses radius 12 and samples 25, BarSlider and BarSliderPopup compute
// samples = 1 + radius * 2 - so a focus move, which scales and re-renders
// several items at once, costs several full-size FBO round trips in the frame
// it lands on.
//
// Nothing here needs the source pixels: every call site shadows a rounded
// rectangle. So the shadow is evaluated analytically instead - the signed
// distance to a rounded box, smoothed by the blur radius - in one pass, with
// no texture read, no offscreen buffer and no repaint dependency on the item
// it sits behind. Animating the target no longer invalidates anything.
//
// The property names match the stock component exactly, because the call
// sites are LG's and stay unmodified.
import QtQuick 2.12

Item {
    id: root

    property var horizontalOffset
    property var verticalOffset
    property var boxRadius          // blur radius, in px
    property var boxShadowColor
    property var boxTransparentBorder   // accepted, unused: nothing is clipped here
    property var boxSamples             // accepted, unused: cost no longer scales with it
    property var boxOpacity
    property var boxSpread
    property var boxScale
    property Item target
    // Every call site binds `active`, because the stock component is a Loader
    // and that is how the shadow is switched off when a button loses focus.
    // Assigning it is what makes the component API-compatible: a missing
    // property here is a fatal binding error, and it takes the whole panel
    // down with it - Quick Settings then never leaves its launching state.
    property bool active: true

    anchors.fill: target
    visible: active && target && target.visible
    scale: boxScale ? boxScale : 1

    readonly property real _blur: Math.max(0.5, boxRadius ? boxRadius : 0)
    readonly property real _spread: boxSpread ? boxSpread : 0
    readonly property real _dx: horizontalOffset ? horizontalOffset : 0
    readonly property real _dy: verticalOffset ? verticalOffset : 0
    // The corner radius of the thing being shadowed. Every call site targets a
    // Rectangle, so this is read straight off it; anything else shadows square.
    readonly property real _corner: target && target.radius !== undefined ? target.radius : 0
    // Room for the blur tail and the offset to fall outside the target's own
    // rect. DropShadow relied on transparentBorder for the same thing.
    readonly property real _pad: _blur * 1.5 + _spread + Math.max(Math.abs(_dx), Math.abs(_dy)) + 2

    ShaderEffect {
        anchors.fill: parent
        anchors.margins: -root._pad
        // A call site that sets `visible` directly must not resurrect a shadow
        // its `active` binding has switched off; the stock Loader destroyed the
        // item in that case, so nothing was drawn either way.
        visible: root.active
        opacity: root.boxOpacity !== undefined ? root.boxOpacity : 1

        property size effectSize: Qt.size(width, height)
        property vector2d shadowOffset: Qt.vector2d(root._dx, root._dy)
        // Half-extent of the shadow rect inside this padded item.
        property vector2d halfBox: Qt.vector2d(Math.max(0, root.width / 2 + root._spread),
                                               Math.max(0, root.height / 2 + root._spread))
        property real corner: Math.max(0, root._corner + root._spread)
        property real blur: root._blur
        property color shadowColor: root.boxShadowColor ? root.boxShadowColor : "#4D000000"

        // mediump is enough: the largest coordinate is a 4K OSD dimension, and
        // the result is an 8-bit alpha. highp costs fill rate on this GPU.
        fragmentShader: "
            varying mediump vec2 qt_TexCoord0;
            uniform lowp float qt_Opacity;
            uniform mediump vec2 effectSize;
            uniform mediump vec2 shadowOffset;
            uniform mediump vec2 halfBox;
            uniform mediump float corner;
            uniform mediump float blur;
            uniform lowp vec4 shadowColor;

            mediump float sdRoundBox(mediump vec2 p, mediump vec2 b, mediump float r) {
                mediump vec2 q = abs(p) - b + r;
                return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
            }

            void main() {
                mediump vec2 p = qt_TexCoord0 * effectSize - effectSize * 0.5 - shadowOffset;
                mediump float d = sdRoundBox(p, halfBox, min(corner, min(halfBox.x, halfBox.y)));
                // smoothstep across the blur band approximates the Gaussian
                // falloff closely enough at these radii, in one instruction.
                mediump float a = 1.0 - smoothstep(-blur, blur, d);
                gl_FragColor = vec4(shadowColor.rgb * shadowColor.a, shadowColor.a) * a * qt_Opacity;
            }
        "
    }
}
