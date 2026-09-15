# Motion Design & GPU Rendering for 10-Foot TV UIs

## Cheap vs Expensive on TV GPUs

### Cheap Effects (GPU-Friendly)
- **Transform and opacity animations**: Skip layout and paint entirely, run on dedicated GPU thread, achieve 60fps even when main thread is busy; use `transform: translate()`, `scale()`, `rotate()` instead of animating layout properties. https://www.smashingmagazine.com/2016/12/gpu-animation-doing-it-right/
- **Z-index reordering without layout**: Opaque primitives can be freely reordered in the scene graph without affecting overdraw; renderer uses OpenGL Z-buffer with unique z positions per primitive. https://doc.qt.io/qt-6/qtquick-visualcanvas-scenegraph-renderer.html
- **Multisample antialiasing on subtrees only**: Applying multisampling to a given subtree leads to significant performance gains since multisampling is not applied to other scene parts. https://doc.qt.io/qt-6/qml-qtquick-effects-multieffect.html

### Expensive Effects (GPU-Intensive)
- **Fullscreen Gaussian blur**: Requires substantial GPU cost; fullscreen gaussian blur with moderate samples runs at 60fps only on high-end graphics hardware. https://doc.qt.io/qt-6/qml-qt5compat-graphicaleffects-gaussianblur.html
- **ShaderEffect without caching**: Items using layers/shaders cannot be batched during rendering, significantly impacting performance in complex scenes; avoid ShaderEffect in delegates. https://doc.qt.io/qt-6/qtquick-performance.html
- **ShaderEffectSource (FBO rendering)**: Causes scene to prerender into FBO before drawing; overhead is quite expensive; in most cases decreases performance and always increases video memory usage. https://doc.qt.io/qt-6/qml-qtquick-shadereffectsource.html
- **Blending-enabled ShaderEffect**: When fragmentShader output is blended with background using source-over blend mode, performance decreases significantly; disable blending when not needed. https://doc.qt.io/qt-6/qml-qtquick-shadereffect.html
- **Overdraw and opacity changes**: Any change of opacity, shader, texture, clipping, or render target results in new batch (worse performance); renderer separates opaque primitives from alpha-blended ones. https://doc.qt.io/qt-6/qtquick-visualcanvas-scenegraph-renderer.html

### MediaTek TV Chip Constraints
- **Mali-G31 GPU (MT9602)**: Mid-tier TV chip with Mali-G31 GPU, quad-core Cortex-A55 CPU; supports 4K@60Hz with 2GB RAM configuration. https://www.mediatek.com/products/pentonic/mt9602
- **Video decoding priority**: MediaTek TV chips integrate dedicated video decoders and optimized memory controllers tuned for sustained media playback; prioritizes media pipeline over gaming performance. https://electronics.alibaba.com/buyingguides/mediatek-android-tv-box-guide-which-chipset-fits-your-needs

## Qt Quick Specifics

### Scene Graph Batching
- **Batching fundamentals**: Scene Graph organizes QML items into tree structure where each node represents visual element; using scene graph means scene can be retained between frames and complete set of primitives to render is known before rendering starts. https://doc.qt.io/qt-6/qtquick-visualcanvas-scenegraph.html
- **Batching constraints**: Only rendering commands sharing same pipeline state can be batched; a 10-item UI list with background, icon, text traditionally needs 30 draw calls but scene graph can reduce to 3 through reordering. https://doc.qt.io/qt-6/qtquick-visualcanvas-scenegraph.html
- **Batch visualization**: Set `QSG_VISUALIZE=batches` environment variable to visualize batches; merged batches drawn with solid color, unmerged with diagonal line pattern; few unique colors indicates good batching. https://doc.qt.io/qt-6/qtquick-visualcanvas-scenegraph-renderer.html

### Layer and Caching Strategy
- **Item.layer cost**: An item using layer/shader cannot be batched during rendering; introducing layers breaks batching and reduces optimization opportunities. https://doc.qt.io/qt-6/qtquick-performance.html
- **ShaderEffectSource caching**: Render complex item once into texture (cache), then animate texture freely without re-rendering source; disable cache when source or effect properties are animated to avoid memory waste. https://doc.qt.io/qt-6/qml-qtquick-shadereffectsource.html
- **ShaderEffectSource live property**: Setting `live: false` improves performance by skipping source item rendering and using previously cached texture; `live: true` updates cache every frame (expensive). https://doc.qt.io/archives/qt-5.15/qml-qtquick-shadereffectsource.html
- **Texture size optimization**: Decrease resolution of source item using `ShaderEffectSource.textureSize` property for better performance; more pixels means more GPU work. https://doc.qt.io/qt-6/qml-qtquick-effects-multieffect.html

### Blur Effect Selection
- **FastBlur vs GaussianBlur trade-off**: FastBlur uses source downscaling and bilinear filtering (lower quality, faster); GaussianBlur uses Gaussian function (higher quality, slower); prefer FastBlur for rapidly changing content or when highest blur quality not needed. https://doc.qt.io/qt-5/qml-qtgraphicaleffects-fastblur.html
- **Animating blur properties**: Modifying GaussianBlur properties may require rebuilding shader code from scratch; animating properties performs badly and requires large cache space; FastBlur should be preferred for animated blurs. https://doc.qt.io/qt-6/qml-qt5compat-graphicaleffects-gaussianblur.html
- **FastBlur radius limit**: Visual quality reduced when FastBlur radius exceeds value 64; algorithm internally reduces accuracy to provide good rendering performance. https://doc.qt.io/archives/qt-5.12/qml-qtgraphicaleffects-fastblur.html
- **Blur caching trade-off**: Both FastBlur and GaussianBlur support `cached` property for performance optimization; caching increases memory consumption (extra buffer for effect output) but improves rendering performance when source doesn't change. https://doc.qt.io/qt-5/qml-qtgraphicaleffects-gaussianblur.html

### UniformAnimator Optimization
- **GPU-side animation**: UniformAnimator provides quickest rendering loop; render thread computes animation values in C++ and triggers GPU updates through OpenGL without CPU intervention. https://woboq.com/blog/gpu-drawing-using-shadereffects-in-qtquick.html

## Durations & Easings

### Material Design Motion Durations
- **Standard durations**: Shortest (150ms), shorter (200ms), short (250ms), standard (300ms), complex (375ms), entering screen (225ms), leaving screen (195ms). https://m1.material.io/motion/duration-easing.html
- **Navigation transitions**: Use duration ~300ms as rule of thumb since transitions occupy most of screen; small components like switch use short duration 100ms. https://m1.material.io/motion/duration-easing.html
- **Large vs small animations**: Larger animations on mobile/TV devices are 300–400ms long; smaller animations can be as short as 150–200ms. https://m1.material.io/motion/material-motion.html

### Material Easing Curves
- **Standard Interpolator**: Cubic-bezier(0.2, 0, 0, 1); utility-focused animations that begin and end on screen. https://github.com/material-components/material-components-android/blob/master/docs/theming/Motion.md
- **Standard Decelerate**: Cubic-bezier(0, 0, 0, 1); animations entering screen; element quickly accelerates then gently slows. https://github.com/material-components/material-components-android/blob/master/docs/theming/Motion.md
- **Standard Accelerate**: Cubic-bezier(0.3, 0, 1, 1); animations exiting screen. https://github.com/material-components/material-components-android/blob/master/docs/theming/Motion.md
- **Most navigation use**: Most nav transitions use Material's standard easing, which is asymmetrical; elements quickly speed up then gently slow down to focus attention on transition end. https://medium.com/google-design/motion-design-doesnt-have-to-be-hard-33089196e6c2

### Roku Motion Principles
- **Simple, clean animations**: Use minimal animations to help users see and follow system transition from one state to another. https://developer.roku.com/dev/docs/key-design-principles
- **No animation throttling**: Never make users wait on animations; UI animations should not act as governor to throttle interaction pace. https://developer.roku.com/dev/docs/key-design-principles
- **Responsiveness over animation**: System must respond immediately to every user action with clear, distinct feedback; animations are supportive visual aids, not primary interaction mechanisms. https://developer.roku.com/dev/docs/key-design-principles

### tvOS Focus Animation
- **Focus scale factor**: Focused item uses scale transform (typically 1.05x–1.1x) unmistakably distinguished from unfocused items using scaling, elevation via shadow, brightness changes, or border highlights. https://devsign.co/notes/custom-focus-effects-in-tvos
- **Focus animation coordination**: Use `didUpdateFocus(in:with:)` method with `UIFocusAnimationCoordinator` to add and remove parallax effects inside animation block to avoid glitches. https://developer.apple.com/library/archive/documentation/General/Conceptual/AppleTV_PG/WorkingwiththeAppleTVRemote.html

## Parallax & Depth

- **Layer count**: Parallax artwork required to have between 2–5 layers to create proper sense of depth when brought into focus; minimum 2 layers for app icon. https://developer.apple.com/library/archive/documentation/General/Conceptual/AppleTV_PG/CreatingParallaxArtwork.html
- **Automatic parallax treatment**: UI elements specifying appropriate layers automatically get parallax effect treatment when in focus; system handles transform, shadow, glare, tilt, shift. https://developer.apple.com/library/archive/documentation/General/Conceptual/AppleTV_PG/CreatingParallaxArtwork.html
- **UIInterpolatingMotionEffect parameters**: Tracks horizontal and vertical tilt; for tvOS tied to user's finger location on Siri remote. https://medium.com/@OddNetworks/replicating-tvos-parallax-focus-effect-on-custom-uiviews-ed9a8fa266a8
- **Shadow performance optimization**: Providing appropriate `shadowPath` to parallax shadow method improves performance significantly. https://github.com/asynchrony/Re-Lax
- **Animation block requirement**: Add and remove parallax effect inside animation block to avoid visual glitches. https://github.com/PGSSoft/ParallaxView
- **Parallax and shadows for distance**: Big shadows are easier to see when focused at 3-meter distance. https://medium.com/bpxl-craft/getting-started-with-apple-tv-human-interface-guidelines-4d991737ddec

## Ambient/Idle & OLED Safety

- **Pixel shifting technique**: Alternates active pixels to minimize stress on each and reduce image sticking; dithering in pixel position delays burn-in by translating displayed image one pixel at a time. https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/10475417
- **Luminance reduction on stationary pixels**: Detecting bright stationary pixels (logos) so luminance reduction can be applied on stationary regions. https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/12051364
- **Video screensaver safety**: Constant movement distributes pixel wear evenly; avoid persistent static elements (watermarks, logos). https://techjunctions.com/samsung-tv-screensaver/
- **Brightness exponential risk**: 100% brightness degrades pixels 4–5x faster than 50% brightness. https://us.ktcplay.com/blogs/support-tips/oled-burn-in-practical-prevention
- **Safe ambient settings**: Dark rotating wallpaper or subtle motion background; screensaver/black screen after ~5min inactivity. https://us.ktcplay.com/blogs/support-tips/static-wallpaper-oled-burn-in-prevention
- **Google TV Ambient Mode**: Designed to avoid displaying static images for extended periods. https://developer.android.com/training/tv/playback/ambient-mode
- **Samsung mandatory screensaver**: OLED TVs activate a screensaver after 2 minutes of inactivity; cannot be disabled. https://techjunctions.com/samsung-tv-screensaver/
- **Safe content characteristics**: Continuous movement across entire screen, varied dynamic content, reduced brightness (50–60% or lower), no persistent logos/UI, high color variation. https://www.viewsonic.com/library/gaming/oled-burn-in-what-it-is-why-it-happens-and-how-to-stop-it/
- **Vestibular motion triggers**: Scaling or panning large objects can trigger discomfort; 10-foot interfaces should respect reduce motion. https://en.wikipedia.org/wiki/10-foot_user_interface
- **Distinguish animation types**: Disable decorative motion entirely; reduce but keep functional motion. https://designsystemproblems.com/accessibility-compliance/reduced-motion-preferences/
- **Replace motion intelligently**: Replace sliding with fade; use color and fading for feedback. https://blog.pope.tech/2025/12/08/design-accessible-animation-and-movement/

## Image Loading

- **Visibility-based loading**: Load images just before viewport entry; limit requests to visible items; rapid scroll should not trigger requests unless item visible for a period. https://dev.to/itepifanio/horizontal-scroll-with-lazy-loading-578c
- **BlurHash placeholders**: Jellyfin uses BlurHash for placeholders and progressive loading; limits resolution to 128×128 pixels. https://deepwiki.com/jellyfin/jellyfin/2.2-image-processing
- **Off-thread image decoding**: Decode off the UI thread; decoding time is proportional to image size. https://learn.microsoft.com/en-us/archive/blogs/slmperf/off-thread-decoding-of-images-on-mango-how-it-impacts-your-application
- **View recycling**: Render only visible items and recycle views to reduce memory and improve scroll performance. https://medium.com/@andrew.chester/react-native-infinite-scrolling-with-lazy-loading-a-step-by-step-guide-e91647348689
