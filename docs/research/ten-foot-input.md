# Interaction Design for TV Remotes with D-pad and Pointer Input

## Focus Indication

- **Scale factor for focus:** tvOS uses 1.05x–1.1x scaling for focused items; must be unmistakably distinguished from unfocused using scaling, elevation via shadow, brightness changes, or border highlights—never color alone. https://lobehub.com/skills/ehmo-platform-design-skills-tvos
- **Parallax effects on tvOS:** Focused items include a scale transform, shadow (lift effect), white glare reflecting a light source, blurry white circle mask, and 3D parallax tilt responding to trackpad nudges; use Xcode's LSR (Layered Static Image) format for automatic animation. https://devsign.co/notes/custom-focus-effects-in-tvos
- **Minimum hit target size (tvOS):** 250×150 pt for cards; smaller elements are difficult to land on with swipe-based navigation. https://remoteopenclaw.com/skills/ehmo/platform-design-skills/tvos-design-guidelines
- **Focus ring contrast (WCAG 2.1):** SC 2.4.7 requires visibility only, no specific color contrast. WCAG 2.2 SC 2.4.11 requires 3:1 contrast for UI components; two-color outline (white + black lines) ensures visibility on all backgrounds. https://www.w3.org/TR/WCAG22/
- **BBC GEL focus specification:** 2 px focus rings on all interactive targets; focus must be visible with adequate contrast against all backgrounds where it appears. https://bbc.github.io/gel/foundations/focus/
- **Focus must be clear from distance:** Every interactive element needs a clearly visible focus state with unmistakable visual distinction (bold borders, color changes, scaling) visible from sofa viewing distance. https://spyro-soft.com/blog/media-and-entertainment/8-ux-ui-best-practices-for-designing-user-friendly-tv-apps

## Focus Movement

- **Android TV/Leanback spatial algorithm:** Proximity-based: D-pad finds the geometrically closest focusable element in that direction, even if misaligned with expected grid row/column. This can cause unexpected focus jumps. https://mlangendijk.medium.com/learning-focus-management-in-smart-tv-apps-0bdb17da3795
- **Grid wrap-around (Leanback):** Focus does not wrap automatically at grid edges; default behavior allows focus to escape grid boundaries; wrap-around must be explicitly configured via `setFocusOutAllowed()`. https://github.com/kingargyle/adt-leanback-support/blob/master/leanback-v17/src/main/java/android/support/v17/leanback/widget/GridLayoutManager.java
- **tvOS grid focus engine:** Automatically evaluates layout geometry and builds a focus map; as long as the interface follows clear grid logic, focus movement aligns with expectations. Default tvOS does not wrap horizontally—custom logic required to wrap from last item back to first. https://www.oxagile.com/article/tvos-focus-engine-navigation-guide/
- **Focus memory per row (Android TV):** When users move focus between left and right panels, focus should return to the last focused item in that panel on re-entry; implement via ViewModel-based state or persistent storage. https://oleksii-tym.medium.com/android-tv-advanced-focus-requester-manipulation-7569e818a734
- **Roku grid navigation:** Grid nodes automatically respond to D-pad (Up, Down, Right, Left) by moving focus to the next item in that direction; focus is unique per tree node; key event passes up node hierarchy if not handled. https://developer.roku.com/dev/docs/list-and-grid-nodes
- **Edge behavior on tvOS:** If a gap exists in the grid, default focus engine may jump over sections to focus a cell several sections away in the same column; best practice is to build layout so geometry produces correct movement without customization. https://github.com/MicrosoftDocs/xamarin-docs/blob/live/docs/ios/tvos/app-fundamentals/navigation-focus.md
- **Focus guides (tvOS):** `UIFocusGuide` creates invisible focusable regions that redirect focus to correct cells, useful for empty spaces or layout gaps. https://code.tutsplus.com/tutorials/taking-control-of-the-tvos-focus-engine--cms-26572

## Animation Timing

- **Android Leanback focus animation:** Default duration is 150 milliseconds for focus highlight animation (scaling and dimming); customizable via `FocusHighlightHandler`. https://github.com/kingargyle/adt-leanback-support/blob/master/leanback-v17/src/main/java/android/support/v17/leanback/widget/FocusHighlightHelper.java
- **Material Design motion durations (Google TV):** Larger animations are 300–400 ms; smaller animations 150–200 ms. Adjust duration for distance travelled, object velocity, and surface changes. Objects leaving screen use shorter durations; large distance or dramatic surface changes use longer durations. https://m1.material.io/motion/duration-easing.html
- **Material Design easing (Google TV):** Standard curve (ease-in-out) most common: elements accelerate quickly and decelerate slowly. Asymmetric acceleration/deceleration produces natural, delightful motion. https://m1.material.io/motion/duration-easing.html
- **Animation style trade-offs:** Simple, functional style uses short durations, standard easing, linear motion paths; dramatic, emphasized style uses longer durations, emphasized easing, arc motion. https://medium.com/google-design/implementing-motion-9f2839002016

## Pointer Mode

- **LG Magic Remote mode switching:** Pressing Up, Down, Left, or Right key while pointer is active switches remote to 5-way mode, disabling pointer function. In 5-way mode, cursor is not displayed; in pointer mode, cursor is displayed. https://webostv.developer.lge.com/develop/guides/magic-remote
- **LG cursorStateChange event:** Fired when Magic Remote pointer cursor visibility changes; supported on webOS TV 2.x+. JavaScript handler checks `event.detail.visibility` to detect cursor appearance/disappearance. https://webostv.developer.lge.com/develop/references/webos-event
- **Samsung Smart Remote pointer modes:** Button-press mode requires holding POINTER button (clear feedback, works with unstable Bluetooth); air mouse (continuous motion) requires no button press, seamless but requires consistent ambient conditions. Requires Tizen OS v6.0+ (2021+). https://electronics.alibaba.com/buyingguides/samsung-smart-tv-remote-pointer-guide
- **tvOS trackpad design (no pointer):** Apple TV uses focus-based navigation only, no cursor. Siri Remote 1st gen has glass multi-touch surface; 2nd gen has circular click pad. Users move focus via touch surface swiping, not pointer. https://remoteopenclaw.com/skills/ehmo/platform-design-skills/tvos-design-guidelines
- **Fire TV pointer support:** Fire TV supports USB/Bluetooth mouse but requires remote D-pad as primary mode for app acceptance. Pointer customizable via Android manifest. https://developer.amazon.com/public/solutions/devices/fire-tv/docs/customizing-mouse-pointer
- **Cursor auto-hide timeout:** Common defaults are 10 seconds (widespread), 5 seconds (popular), 3 seconds (presentations). Most utilities offer 3–5–10–30–60 second presets. https://hidecursor.emp0ry.com/
- **WCAG pointer hit target (AA):** Minimum 24×24 CSS pixels for pointer inputs; exceptions: targets in text, offsets ≥24 px to adjacent targets, or geographically essential positioning. WCAG AAA recommends 44×44 px. https://wcag.dock.codes/documentation/wcag258/
- **Air mouse gyro stabilization:** Six-axis gyro (3-axis gyro + 3-axis accelerometer) minimum for usable cursor stabilization. Best units offer adjustable DPI or pointer speed settings to dial in response curve; without this, cursor may overshoot small buttons or miss subtle movements. https://wellfizz.com/best-air-mouse/
- **Samsung pointer mode activation:** Requires optical alignment between remote tip and TV bezel for reliable motion sensing; Bluetooth transmits commands but motion detection is optical. https://sofiadigital.com/pointer-events-for-smart-tv-applications/

## Multi-row Grids & Edit Mode

- **Roku app reordering:** Press asterisk (*) button while app is highlighted to launch options menu, select "Move channel" or "Move app" to activate drag mode, use D-pad arrows to reposition, press OK to lock. https://tms-outsource.com/blog/posts/how-to-move-apps-on-roku/
- **Fire TV app reordering:** Press and hold Select button, choose "Move" or "Reorder," then navigate with D-pad. Alternatively, highlight app in full apps list, press Menu, select "Move" or "Unpin"/"Pin to Front." https://amazon.com/gp/help/customer/display.html?nodeId=GEE43R7R6NPT4MRA
- **Android TV row reordering:** Select "Reorder," move the row where needed, press center D-pad button to confirm. https://support.google.com/androidtv/answer/6121336?hl=en
- **Android development drag-drop:** Implement via long-press to activate drag mode, move to desired position, lift to drop; libraries like DragListView support drag-drop reordering on RecyclerView for lists, grids, boards. https://github.com/woxblom/DragListView
- **Drag gesture semantics:** Press, move, lift actions rearrange data within a view or move data into containers. Long-press triggers drag mode. https://stuff.mit.edu/afs/sipb/project/android/docs/design/patterns/gestures.html
- **Google TV browser template layout:** Media content organized as vertical stack of horizontal rows; users navigate up/down between rows, left/right within rows. https://developer.android.com/design/ui/tv/guides/styles/layouts
- **tvOS horizontal swiping preference:** Swiping left-right on Siri Remote is more natural than up-down, so horizontal content navigation should be favored in layout design. https://www.oxagile.com/article/tvos-focus-engine-navigation-guide/

## Back & Re-entry

- **Android TV back semantics:** Repeated back button presses must eventually lead to home screen without infinite loops. Back navigates breadcrumb-style through previous screens, never acts as toggle. https://developer.android.com/training/tv/get-started/controllers
- **Fire TV back semantics:** Back button returns to previous screen within app (one step), dismisses menus, closes keyboards. Home button jumps to Fire TV home screen from any app. Back navigates app history; Home exits to system. https://remotesinfo.com/fire-tv-remote-buttons-explained/
- **Apple TV back semantics:** Single press goes to previous screen; long-press (hold) goes to Home Screen. Creates dual-function model. https://support.apple.com/en-mz/guide/tv/atvbe55a4b4e/15.0/tvos
- **Platform back button distinction:** Android TV uses linear stack-based back (app root → system home); Fire TV and Apple TV use context-sensitive back (previous screen in app) vs. dedicated Home button (exit to system). https://blog.mercury.io/designing-great-streaming-tv-apps-pt-2-top-or-left-navigation/
- **Focus restoration on re-entry:** When user navigates away then returns, focus should restore to last position in that region. Store focus state in ViewModel (persists while ViewModel alive) or database (survives configuration changes). https://alexzaitsev.substack.com/p/focus-as-a-state-new-effective-tv
- **Focus memory between panels:** When moving focus between left/right panels, focus should return to last focused item in that panel on re-entry. https://oleksii-tym.medium.com/android-tv-advanced-focus-requester-manipulation-7569e818a734
- **Android TV Leanback VerticalGridView/HorizontalGridView:** Recommended components extending RecyclerView; best approach for multi-row grids with reliable focus handling and restoration. https://georgimirchev.com/2022/07/07/recyclerview-loses-focus-when-scrolling-fast-or-how-to-use-it-on-android-tv/

## LG webOS Specific

- **Magic Remote mode switching mechanism:** Pressing any arrow key (Up, Down, Left, or Right) while in pointer mode automatically switches to 5-way D-pad mode; pressing arrow keys re-enters 5-way navigation. This is the primary mode-switch interaction. https://webostv.developer.lge.com/develop/guides/magic-remote
- **webOS events architecture:** Developers handle cursor state via `cursorStateChange` event listener; visibility status returned in `event.detail.visibility` (true = cursor visible, false = cursor hidden). Handler invoked when remote transitions between pointer and 5-way modes. https://webostv.developer.lge.com/develop/references/webos-event
- **webOS 1.x vs 2.x+:** `cursorStateChange` event not supported on webOS 1.x; must use `keydown` event to infer cursor state. webOS 2.x and later fully support the event. https://webostv.developer.lge.com/develop/guides/system-ui-visibility
- **Magic Remote pointer event handling:** Apps must respect mode transitions; when arrow key pressed in pointer mode, app receives keydown (not pointer move) and should transition UI to D-pad focused mode, hiding pointer cursor. https://webostv.developer.lge.com/develop/guides/magic-remote
- **Dual-mode app design requirement:** Every feature must be accessible using remote D-pad alone; pointer mode is supplementary for apps that benefit from it (menus, grids) but cannot be the sole input method. https://developer.samsung.com/smarttv/design/input-methods.html
- **Pointer & 5-way coexistence:** webOS home screen can support both simultaneously—pointer activates item selection without exiting pointer mode; D-pad presses dynamically switch to 5-way mode. Cursor hiding happens automatically on mode switch. https://webostv.developer.lge.com/develop/guides/system-ui-visibility

---

**Viewing distance context:** All specifications assume 10-foot (3 m) viewing distance. Text sizes scale via ISO 9241-303 formula: minimum text height = distance (feet) × 0.01–0.014; for 10 feet, minimum body text ~36 pt, recommended 40.8–50.4 pt, headlines ≥72 pt. At 1080p, Amazon TV recommends 28 px minimum. https://digitalsignage.com/digital_signage/docs/guides/typography-viewing-distance/ https://www.alicia.design/post/solving-small-text-and-contrast-issues-for-large-screen-readability

**Press-and-hold pattern:** Modern remotes (Apple, Samsung, LG) use long-press to extend button functionality, doubling capabilities without physical buttons—common for edit mode activation, long-press animations (200–500 ms before mode change detected). https://www.smashingmagazine.com/2025/09/designing-tv-principles-patterns-practical-guidance/

**Motion control baseline:** D-pad navigation limit is four directions (up, down, left, right) plus select/OK. Every interactive component requires clear focus state and predictable flow. Grid-based layouts with correct geometry require no custom focus logic. https://spyro-soft.com/blog/media-and-entertainment/8-ux-ui-best-practices-for-designing-user-friendly-tv-apps
