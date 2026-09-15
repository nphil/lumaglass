# 10-Foot TV UI Research: Design Fundamentals

## Safe Areas & Overscan Margins

- **tvOS standard insets**: 60 points top/bottom, 80 points left/right to keep critical content within safe area; overscan still crops edges on many TV sets due to legacy broadcast standards. [https://www.smashingmagazine.com/2025/09/designing-tv-principles-patterns-practical-guidance/]
- **Google TV margin**: 5% layout margin recommended; for 960×540px layout, use 58dp on left/right and 28dp on top/bottom. [https://developer.android.com/design/ui/tv/guides/styles/layouts]
- **Roku safe zones**: HD Title Safe (1022×578px, offset 128,70), HD Action Safe (1150×646px, offset 64,35); 5% margin minimum to prevent overscan cropping. [http://wwwimg.roku.com/static/sdk/DesignGuidelines.pdf]
- **Fire TV**: Content must be placed on action-safe area (inner area within 5% margin); overscan varies by TV model. [https://developer.amazon.com/docs/fire-tv/design-and-user-experience-guidelines.html]
- **Samsung Tizen**: 5% margin hides picture edges; active UIs on action-safe area only. [https://lists.w3.org/Archives/Public/public-secondscreen/2016Jun/0087.html]
- **LG webOS icon padding**: Minimum 5px padding inside 115×115px icon area to display properly. [https://webostv.developer.lge.com/develop/guides/icon]

## Typography

- **Android TV minimum**: 24sp body text, 48sp+ headings; 12sp is technical floor, 18sp default. [https://developer.android.com/design/ui/tv/guides/styles/typography]
- **tvOS font weight**: Avoid thin/light typefaces; thin strokes disappear at TV viewing distances due to motion blur and compression artifacts; use medium or semibold minimum. [https://www.lobehub.com/skills/dirnbauer-webconsulting-skills-tvos-design]
- **Fire TV/Amazon recommendations**: 28px minimum at 1080p viewing; 32pt for larger displays; both values are minima not targets—exceed where possible. [https://www.alicia.design/post/solving-small-text-and-contrast-issues-for-large-screen-readability]
- **Line length**: Max 30 characters per line; no more than 3 lines displayed at once; 50–75 CPL (66 optimal) for general body text adapted to distance. [https://legibility.info/rules-for-text-in-videos]
- **System typefaces**: Android TV = Roboto; Samsung Tizen = One UI Sans; Apple = San Francisco; BBC GEL = Reith. All optimized for legibility at distance; sans-serif with clear, open forms required. [https://developer.android.com/design/ui/tv/guides/styles/typography] [https://developer.samsung.com/tv/design/apps-screen/] [https://bbc.github.io/gel/foundations/typography/]
- **Line spacing**: Generous spacing avoids slippage during lean-back viewing; BBC GEL range 15–18px body depending on screen size. [https://www.coeno.com/en-blog/typography-for-tv-applications]

## Colour & OLED

- **Burn-in mitigation hardware**: Pixel shifting (1–2px micro-shifts distribute wear invisibly); brightness modulation (blue intensity reduced 15–20% in static UI); frame-rate control (120Hz→60Hz for static content); sub-pixel alternation halves cumulative pixel usage. [https://eureka.patsnap.com/blog/how-to-prevent-oled-burn-in/]
- **UI design principle**: Reduce static element exposure first, then use panel protection features as support; static logos, news tickers, game HUDs, desktop UI are high-risk. [https://uperfect.com/blogs/wikimonitor/oled-burn-in]
- **OLED detection systems**: Bright stationary pixels (logos) require processing to apply luminance reduction and slow burn-in. [https://image-ppubs.uspto.org/dirsearch-public/print/downloadPdf/12051364]
- **Static element strategies**: Auto-hide non-essential overlays after timeout; apply imperceptible position drift to static text; use lower-luminance for persistent UI, reserve full brightness for dynamic content. [https://us.ktcplay.com/blogs/support-tips/oled-burn-in-prevention-mixed-work-gaming]
- **Contrast ratio requirement**: WCAG AA minimum 4.5:1 normal text, 3:1 large text (18.66+px or 24px+ bold); pixel size scales with viewing distance, making requirement effectively less stringent at TV distances. [https://webaim.org/resources/contrastchecker/]
- **Light-on-dark legibility**: Light text on dark background is more legible on TV screens than dark-on-light. [https://www.coeno.com/en-blog/typography-for-tv-applications]

## Grid & Spacing

- **Android TV 12-column grid**: 52dp columns, 20dp gutters; 5% margin (48dp left/right, 27dp top/bottom); 960×540px base design resolution upscales to HD/4K. [https://developer.android.com/design/ui/tv/guides/styles/layouts]
- **Google TV grid**: 12 columns ×52dp, 20dp gutters; 48dp left/right margins, 27dp top/bottom; 4dp baseline vertical spacing. [https://websiddu.com/work/design-systems-google-tv]
- **Samsung Tizen principle**: Grid-based layout (4-directional D-pad navigation); diagonal placements confuse users about next navigation target; grid minimizes confusion. [https://developer.samsung.com/smarttv/design/design-principles.html]
- **Roku grid**: 12-column layout recommended; uses 52dp columns with 20dp gutters. [http://wwwimg.roku.com/static/sdk/DesignGuidelines.pdf]
- **Layout density philosophy**: Information density must match mobile phone displays, not desktop; users 10 feet away cannot process as much detail; simplicity and clarity required. [https://developer.android.com/design/ui/tv/guides/styles/layouts]

## Tiles & Information Density

- **Card aspect ratios**: Three standard ratios: 16:9, 1:1, 2:3; six card variations (standard, classic, compact, inset, wide standard, wide classic). [https://developer.android.com/design/ui/tv/guides/components/cards]
- **Minimum tile dimensions**: 16:9 poster minimum 1280×720px (HD); 1920×1080px practical minimum (Full HD); 3840×2160px preferred (4K). [https://itunespartner.apple.com/tv-movies/support/5450-artwork-requirements]
- **Apple TV artwork**: 16:9 keyframe minimum 1920×1080px but 3840×2160px preferred; PNG/JPG/LSR; 3840×2160px at 72dpi Display P3 for premium content. [https://itunespartner.apple.com/tv-movies/support/5450-artwork-requirements]
- **Optimal grid density**: Single row of 5–7 cards preferable to dense 20+ thumbnail grid; Fire TV grids contain 2–4 tiles per row with content remaining on-screen during scroll. [https://www.lobehub.com/skills/dirnbauer-webconsulting-skills-tvos-design]
- **Information density limit**: Amount of information comparable to mobile phone display, not desktop; limit text/reading, ensure elements large enough and spaced far apart for 10-foot distance. [https://developer.amazon.com/docs/fire-tv/design-and-user-experience-guidelines.html]
- **Google TV density**: Avoid heavy density; groupings become visually busy; spacing organizes content and creates visual calm at typical 10-foot viewing. [https://websiddu.com/work/design-systems-google-tv]

## Widget Layouts

- **Google TV Your Apps row**: Redesigned circular icons instead of square; 12 apps displayable without expanding full list; includes reorder and add-app buttons. [https://www.androidpolice.com/google-tv-home-screen-redesign-your-apps-row/]
- **Android TV home customization**: Custom widgets, app rows, layout tweaks supported; third-party launchers (like Projectivy) provide grid control, widget grouping, category organization. [https://glance.com/us/articles/customize-android-tv-home-screen]
- **Projectivy launcher flexibility**: Supports single-row or grid layouts with configurable items-per-row; customizable spacing, icon size, accent color; organizes apps into categories (Favorites, Video, Music, Games). [https://www.xda-developers.com/google-tv-bloated-replaced-custom-launcher-actually-works/]
- **Kodi Arctic Zephyr 2 skin**: App-like layout with category/widget options; supports multiple home layouts, widget layouts, hubs, submenus, spotlight viewtypes; clean white/grey design with large poster display and bottom scrollbar. [https://www.videoconverterfactory.com/kodi/arctic-zephyr-2.html]
- **Arctic Zephyr widget system**: Accessed via Skin Settings → Customize Main Menu; all home layouts, widget placement, fanart customizable; designed clean/simple but multifunctional and widgets-rich. [https://www.addictivetips.com/media-streaming/kodi/customize-arctic-zephyr-skin/]
- **Google TV navigation redesign**: Top bar shows "Home," "Live," "Apps" tabs in pill-shaped bar with search at far left; screensaver and quick settings icons; replaced older "For You" tab. [https://9to5google.com/2025/11/13/google-tv-homescreen-redesign-2025/]

## Materials & Glassmorphism/Blur

- **Apple Liquid Glass system**: Dynamic translucency (glass samples underlying content in real-time); morphing transitions; ambient reflections; built on optimized shaders reflecting/refracting surroundings. [https://medium.com/@imrnshk199/translucent-interfaces-how-glassmorphism-is-shaping-modern-ios-design-df43a5358e0c]
- **SwiftUI material hierarchy**: Five levels: `.ultraThinMaterial`, `.thinMaterial`, `.regularMaterial`, `.thickMaterial`, `.ultraThickMaterial`; varying translucency and blur. [https://medium.com/@imrnshk199/translucent-interfaces-how-glassmorphism-is-shaping-modern-ios-design-df43a5358e0c]
- **Blur legibility challenge**: More background blur reduces distinction of elements behind it; text legibility is primary failure point; solution: pair blur with semi-transparent overlay (10–30% white/dark tint) to create text-background contrast without killing effect. [https://medium.com/design-bootcamp/glassmorphism-the-most-beautiful-trap-in-modern-ui-design-a472818a7c0a]
- **Transparency adaptation**: Apple addresses blur legibility by adapting materials when accessibility settings (Reduce Transparency) enabled; system-level handling prevents contrast degradation. [https://www.swiftfoxx.org/all-about-glass-effect/]
- **tvOS tab bar application**: Tab bar translucent, overlays content with blur effect; Liquid Glass helps establish hierarchy—foreground controls stand out without solid boxes while background remains visible (softened). [https://www.lobehub.com/skills/dirnbauer-webconsulting-skills-tvos-design]
- **Focus hierarchy principle**: Glass keeps context (users see what's behind), establishes hierarchy (foreground clear, background softened), and maintains depth without solid chrome. [https://vagary.tech/blog/apple-liquid-glass-flutter-react-native-compose-mp]
- **Best practice verification**: Screenshot panel over busiest background; test small body text (not heading); text over busy backgrounds fails legibility first—this is the practical legibility test. [https://theplusaddons.com/blog/liquid-glass-ui/]
- **tvOS 10-foot constraints**: Every design decision must account for 10-foot viewing distance, simple remote, lean-back consumption; icon-only tabs insufficient; all tabs require text labels for clarity. [https://www.remoteopenclaw.com/skills/ehmo/platform-design-skills/tvos-design-guidelines]
- **Focus indicator sizing**: Default scaling 1.025×, 1.05×, or 1.1× depending on element size; scaling values vary by component; minimum 2 CSS pixel thick perimeter required. [https://developer.android.com/design/ui/tv/guides/styles/focus-system]
- **Pointer mode target sizes**: Minimum 15–20px recommended; mouse pointer intentionally large for distance readability; LG allows pointer size adjustment via Settings > Accessibility > Pointer Settings > Pointer Size. [https://www.lg.com/uk/support/product-support/troubleshoot/help-library/cs-CT00008386-20155146347349/]
