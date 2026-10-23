# LumaShell implementation plan

LumaShell (formerly LumaGlass) replaces every visible part of the LG C4's
interface with surfaces in the Lucent design language, while webOS keeps
providing tuning, inputs, playback and settings. The current Home is the
visual reference. Nothing is written to `/usr`; each surface is switched on
through a reversible hook and falls back to LG's own on failure.

Design language: `skill://design-language` (Lucent v2, TV profile). Surface
inventory snapshot of the firmware: `/data/home/lgtv/uiinv`.

## Status

Kept current with every change to this plan. Building starts on Nitin's go.

- Done: resident Quick Settings, resident LumaHome (idle while hidden), key
  filter written only on change, Home stub tested on the set and reverted,
  ambient-light hardware chosen.
- In design: Settings, windows and AI access mockups (`docs/mocks/`).
- Waiting on Nitin: go to build; Lucent focus and depth; wallpaper motion
  rate; disk cache; wall mount or stand; AI access transport; the open
  decisions at the end.
- TV tests when the set is free: receiver volume drift, histogram during
  Netflix, which input device network and CEC keys arrive on, pointer cost.
- Next build step: phase 1.

## Rules every surface meets

- Built once and kept resident; an open shows the item and moves focus. A
  cold build freezes one frame for the whole build: Quick Settings 215-360 ms,
  the input picker 110-190 ms. Resident Quick Settings is fully open at
  170 ms with no frame over 20 ms.
- Shaders, Manrope at every size and weight in use, and icons are warmed at
  compositor start, so a first open never compiles or rasterises.
- Nothing is created per open; list rows are reused; no per-row shadows and
  no live blur. Glass over Home uses the cached wallpaper blur; over video it
  is tinted glass without blur.
- Restyles of LG QML in other processes and of web apps add no cost over what
  they replace: flat fills and the shared shader quad only.
- Gate before cutover, measured with the frame probe over Home and over
  video: no frame over 20 ms and no missed 60 Hz deadline while opening,
  navigating and closing; first frame within 50 ms of the key; fully open by
  180 ms; compositor RSS flat across 500 open/close cycles. A surface that
  fails stays on LG's version.
- One token source: `theme.json` feeds compositor QML directly, QML in other
  processes through a file import, and web apps through generated CSS. One
  typeface: Manrope (the web theme's Inter is replaced).

## Hooks

| Hook | Mechanism | Used for |
|---|---|---|
| System UI redirect | configd `com.webos.surfacemanager.systemUIManager` `appinfo[].main` | Quick panel, input picker, context menu, on-screen remote, boot and power-off logos, nudges |
| View swap | `sysuicompmgr/changeSystemUIView {viewName, viewSource}`; falls back to LG's on load error | Toasts, alerts, PIN prompt, input popups (`notificationView`) |
| Shadow module | `QML2_IMPORT_PATH=/var/lib/lumaglass/qml` first | Volume OSD, launch splash, spinners, recents, window decorations |
| Overlay mount | lowerdir = LG's app dir, upperdir under `/var/lib/lumaglass` | Live TV banners (`inputcommon`, 273 QML), keyboard (maliit, 85 QML), voice/search (203 QML), web apps |
| Key filter and launch redirect | configd `keyFilters`, ours first | Apps tile, notification drawer, entry points |

## Surfaces

| Surface | LG today | LumaShell | Hook |
|---|---|---|---|
| Home | LumaHome over LG's Flutter Home (67 MB resident) | LumaHome only | Phase 8 |
| Apps tile | LG Store (`com.webos.app.discovery`) | Own all-apps grid | Launch redirect |
| Quick panel | 165-file QML, rebuilt per open | Rebuilt resident | System UI redirect |
| Input picker | 51-file QML, rebuilt per open | Rebuilt resident, own inputs only | System UI redirect |
| Volume and mute OSD | Compositor QML; shows webOS's own counter | Rebuilt, fed by the receiver (below) | Shadow module |
| Toasts, alerts, PIN, input popups | `SystemUI/Notification`, 38 files | Rebuilt to the item contract | View swap |
| Launch splash, spinner, long-press ring | Compositor QML | Rebuilt | Shadow module |
| Live TV banner, info, no-signal | `inputcommon` QML | Restyled | Overlay mount |
| On-screen keyboard | maliit QML | Restyled | Overlay mount |
| Search and voice | `com.webos.app.voice` QML | Restyled or replaced | Overlay mount |
| Settings | Web app, +93 MB while open | Own Settings (below); LG's app themed only for its deep screens | Launch redirect + web theme |
| Settings sub-apps | Enact web apps | One shared theme | Overlay mount |
| Notification Centre | Web app | Own drawer | Launch redirect |
| Context menu, on-screen remote | Compositor QML | Rebuilt | System UI redirect |
| Recents, multi-view frames | Compositor QML | Restyled | Shadow module |
| Boot and power-off logo | Compositor QML | Own animation | System UI redirect |
| Screensaver | Flutter | Own, keeping OLED pixel shift | Research |
| Nudges, sports alarm, store promotions | Compositor QML | Off (empty view) | System UI redirect |
| Ad and content-recognition overlays | Native | Off through LG settings | Settings |

Not owned: third-party app UIs (Netflix, YouTube, PlxNative), video, and the
Magic Remote pointer image (native; swap unverified). The pointer stays
supported: every surface has a hover state, and Settings › Remote & pointer
turns it off through `settingsservice` `general.remotePointer` for a
button-only remote. Turning it off removes accidental hover moves; any frame
cost of the pointer itself is measured with the frame probe before claiming
one.

## Receiver volume

webOS's ARC volume is the TV's own up/down counter, not the receiver's level:
`audio/master/getVolume` reports `externalDeviceControl: true`,
`volumeSyncable: false`. It drifts whenever the Denon is adjusted from its own
remote or knob. The third-party Webos-EARC-Volume-Overlay reads that counter
and relaunches a web app per change, so it is neither accurate nor fast, and is
not used.

The LumaShell volume OSD takes its level from the Denon AVR on the LAN instead:
the receiver pushes every master-volume and mute change (`MV`, `MU` events),
so the OSD matches the front panel in the receiver's own units (dB or 0-98),
including changes made on the receiver. The connection lives in the native
helper (below) and is held open; the OSD only renders the last value. It can
also show input and sound mode (e.g. DTS Surround) on change.

Before building:

1. Confirm drift on the set: with the TV and AVR on, change volume on the
   Denon remote and compare `getVolume` with the receiver's level.
2. Check whether this Denon model accepts more than one control connection.
   Home Assistant's Denon integration may already hold it
   (`media_player.living_room_avr`). If only one is allowed, read through
   Home Assistant's WebSocket API instead, at the cost of one hop.
3. Volume keys still go to the receiver through HDMI-CEC as today; LG's own
   volume popup is suppressed only once the OSD has passed the gate.

## Native helper

A static aarch64 helper in Rust runs beside the compositor, in the language
of LumaShow OS so the two share crates rather than reimplement them
(`plugin-api`, `lumashow-sdk`, `settings-schema`, `service-api`, `ha-link`,
`fetch`, `mdns`). A static `aarch64-unknown-linux-musl` build, linked with
`rust-lld`, runs on the set as is (hello world 588 KB). It holds the receiver
connection, the MCP server, the plugin broker and the settings data layer.
The compositor's userspace is 32-bit and stays that way; the helper does not
change rendering cost. News and weather parsing does not justify it on its
own: measured at 0-1 ms per feed on the compositor thread.

## Plugins

LumaShell hosts LumaShow's plugins, so one plugin package runs on every Luma
device. LumaShow's plugin API (`lumashow/docs/plugin-api.md`, level 1)
already fits: a plugin never draws. It declares settings pages, cards, quick
tiles, notifications and timeline items as records, and each device's shell
draws them in its own sizes and for its own input, so the TV draws a card
with remote focus at TV scale and the Show draws it for touch. Plugins are
static aarch64 binaries, and the Show, the Lenovo and the TV are all aarch64,
so the same build installs on each.

- The broker in the helper speaks the same protocol; records become QML
  surfaces in LumaShell: cards on Home, tiles in the quick panel, pages in
  Settings, notifications as LumaShell toasts.
- Device facts in `welcome` (screen class, input methods: touch, remote,
  pointer, controller) are an additive field, for plugins with their own
  views that must adapt; record-only plugins need nothing per device.
- Home's own widgets (weather, news, at home) become first-party plugins once
  the host exists.
- The set's kernel has no user or network namespaces and no seccomp (only
  mount, pid and cgroup isolation), so the Show's sandbox cannot be
  reproduced: plugins run under their own user with mount, pid and memory
  limits, and only reviewed plugins are installed on the TV until network
  access per plugin is enforced another way.

## Settings

LG's Settings (`com.palm.app.settings`, an Enact web app, 25 MB on disk,
+93 MB while open) is replaced by LumaShell's own Settings, drawn in the
compositor and resident like Quick Settings. It writes the same places LG's
app does (`settingsservice` categories such as `picture`, `sound`, `general`,
`option`, and the audio, network and input services), so LG's processing,
panel care and stored values are unchanged; only the screens are new.

- Layout follows LumaShow's Settings ("Live list"): a rail of sections, each
  with a glyph and a one-line summary of its current value, and a page with
  tabs, rows, sliders and switches. Same component kit as LumaShow, Lucent
  tokens, TV sizes.
- Sections: Picture, Sound, Inputs & devices, Network, Ambient light, Home &
  look, Remote & pointer, AI access, System. LG's roughly hundred items are
  curated into these; rare deep screens (expert calibration, channel tuning,
  legal, LG account, software update) stay LG's, themed, behind "More in LG
  settings" rows that open them directly.
- The Settings key, the gear on Home and Quick Settings' "All settings" all
  open it (launch redirect); LG's app remains reachable from System.
- Mockups: `docs/mocks/` (gallery `index.html`, mapping of LG's items to the
  sections in `settings-map.md`).

## AI access (MCP)

The native helper serves an MCP server so AI assistants (Cody, Home
Assistant's agents) can use the TV, with every permission held on the TV and
changed only with the remote. Principle 0 sets the shape: a confirmation an
AI can reach is not a control, so nothing an AI can do is able to grant,
widen or approve its own access.

- Off by default. Settings › AI access turns the listener on (LAN only, bound
  to the LAN address, private source addresses only). Turning it on opens a
  network entrance, so it is done by Nitin with the remote, never through
  MCP, a script or chat.
- Pairing: the TV shows a one-time code; the assistant presents it once and
  receives its own token, stored hashed on the TV. Tokens are created and
  removed only from the TV's screen. "Lock out all AI" revokes every token
  and stops the listener.
- Typed tools only: no raw luna, shell, key-injection or file tools, so an
  assistant cannot drive LG's screens or LumaShell's own menus. Each tool has
  a level set per assistant: Always, Ask on TV, or Never.

| Group | Default |
|---|---|
| See what is playing, power and input state | Always |
| Play, pause, volume, mute | Always |
| Open apps, switch inputs | Ask on TV |
| Change picture and sound settings | Ask on TV |
| Turn the TV off | Ask on TV |
| See the screen (capture) | Never |

- Never exposed, at any level: AI access itself, pairing, network and
  developer settings, uninstalling apps, resets, software updates, LumaShell
  install or updates, the microphone.
- "Ask on TV" opens a LumaShell prompt over whatever is playing: who asks,
  the action in LumaShell's own words, the assistant's reason labelled as
  its own, Allow once or Deny, expiring after 30 s. A denial pauses that
  assistant's requests until it is resumed in Settings. Every call is logged
  and shown in Settings › AI access.
- The prompt and the AI access page answer only to keys from a physical
  remote. All remotes reach the compositor as `lginput2` virtual devices (IR
  `LGE RCU`, Magic Remote `LGE M-RCU`, `IoT keypad` and others), and Home
  Assistant's `webostv.button` presses (SSAP, port 3001) arrive the same way.
  Before building, measure which device SSAP and CEC keys appear on; if
  network keys cannot be told apart from the remote, approvals go through
  HomeLabber's Face ID gate instead of the on-screen prompt.
- TV root bypasses all of this. While an AI holds root SSH on the set (the
  development path today), the permissions bind only assistants that use the
  MCP server; root access for development stays a separate decision of
  Nitin's.

## Compositor startup

`QML_FORCE_DISK_CACHE=1` in `/var/systemd/system/env/surface-manager.env`
overrides LG's global `QML_DISABLE_DISK_CACHE=1`. It cut restart-to-Home from
about 5.8 s to 4.6-5.2 s and does not change cold opens. Adopt through the
tool, with the cache (6.2 MB, `/home/root/.cache/surface-manager/qmlcache`)
cleared on every stage change.

## Ambient light

LumaShell reads the colour of whatever the set is showing and drives the Hue
backlights and an RGBIC strip from it, with no Hue Bridge and no Hue Sync app.
It works during DRM playback (Netflix, Prime, Disney+), where frame capture
returns black on webOS 24 and 25.

Source: LG's own `libvtcapture.so.1` (32-bit, `/usr/lib`) has a histogram API
beside the frame capture: `vtCapture_initHistogram`,
`vtCapture_setPresetHistogram`, `vtCapture_getHistogram`,
`vtCapture_finalizeHistogram`. It returns colour statistics for 16 screen
zones straight from the video hardware. LG's Hue Sync service on the set
(`com.lighting.huesync.service/hue_sync_service`, read only as a reference)
`dlopen`s the library and calls exactly these, logging one r/g/b triple per
zone. hyperion-webos's `HISTOGRAM_OUTPUT` dump location is ordinary frame
capture, not this API.

Design:

- Capture runs in a small 32-bit process, because LG's library is 32-bit; it
  `dlopen`s the library as Hue Sync and hyperion-webos do, polls the zones and
  hands them to the helper. It holds the driver only while there is video and
  the screen is on, and releases it on standby.
- The helper maps zones to lights and smooths them. Features taken from
  HyperHDR as reference: time-based smoothing, brightness and saturation
  gain, per-light white balance and gamma, a dark threshold so black scenes
  turn lights low rather than flicker, black-bar handling for letterboxed
  films, and a delay setting to line light changes up with picture and sound.
- Hue backlights: Hue Entertainment streaming (HueStream over DTLS, the
  protocol Hue Sync and HyperHDR's Hue driver use) to Bifrost, which drives
  the bulbs through Zigbee2MQTT in Zigbee entertainment mode. Plain MQTT light
  commands are too slow for sync and are not used. Gradient lightstrips take
  one colour per segment.
- RGBIC strip: WLED's UDP realtime protocol (DDP), per segment or per LED.
  ESPHome's WLED effect accepts the same protocol, so an ESPHome strip works.
  Vendor strips (Govee and similar) depend on their LAN protocol and are
  checked per model.
- Controls: an Ambient light tile in the quick panel (on/off, intensity), and
  a settings screen that places each light around a picture of the TV, with a
  test pattern. Off on Home and menus unless chosen.
- Gate: no measurable compositor cost; under 1% CPU for capture; light lag
  measured end to end and tuned with the delay setting; capture never stalls
  playback; tested on Netflix, Prime, Disney+, PlxNative, HDMI and Live TV.

Before building, with the set free:

1. Probe: call the four functions during Netflix playback and log the zones;
   find the zone layout (grid or edges), the value range (8-bit, float,
   SDR or HDR), the update rate and the CPU cost. The zones come from the
   video plane, so LumaShell's own UI is likely not in them.
2. Lights: pair the Hue backlights to Zigbee2MQTT (2.14.2, running as a Home
   Assistant app). Bifrost is not installed anywhere yet; installing it is
   Nitin's step. It needs its own IP on the LAN, since it answers as a Hue
   Bridge on ports 80 and 443.
3. Strip, on order: BTF-Lighting FCOB WS2814 RGBW 4000K, 24 V, 5 m (14
   addressable sections per metre, 71 mm each), BTF 10 mm 3-pin FCOB connector
   kit for the corners, Gledopto Elite GL-C-619WL (ESP32, WLED, Ethernet,
   level shifter, relay) and a 24 V 100 W supply. About 58 sections around
   the 65-inch frame; bottom edge depends on wall mount or stand.

## Reference: ecklf/lg-luma

Luma (MIT, Rust/SDL app) is a separate launcher app that the Home key is
rerouted to; LumaShell already owns Home inside the compositor, so only its
ideas are taken, not its architecture.

- Inputs on Home: `com.webos.service.eim/getAllInputStatus` gives each HDMI
  port's label and `connected` flag. Home gets an Inputs row (label, device
  icon, connected state), and each input has Auto / Always / Hidden, Auto
  meaning shown only while something is connected. The same data feeds the
  input picker.
- Device icons per input (console, PlayStation, Apple TV, streamer, computer),
  chosen from the CEC label or by the user.
- All-apps library for the Apps tile: categories (Streaming, Music, Gaming,
  Utilities, matched from app id and title), search with the system keyboard,
  favourites, hide and restore. Luma's filter for what counts as a user app
  (drop invisible apps and system `com.webos.`/`com.palm.`/`com.lge.` ids
  unless marked visible; keep Live TV) is a sound starting rule.
- Key hints along the bottom edge ("OK Open", "Hold OK for options").
- Icons: Lucide (ISC licence) as the UI icon source, rendered once to the
  sizes in use, replacing the hand-drawn PNG set.

## Reference: rudra-avatar/Hearth

Hearth (MIT) is a web launcher that a watcher brings forward over LG's Home.
Taken:

- Boot logo: LG's hidden "Show LG logo when turning on" is
  `settingsservice` `other.lgLogoDisplay` ("on" on this set). Part of the
  clean cold start with the Home stub; offered as a setting, put back on
  `lumaglass off`.
- Saved first, fetched later: the last weather reading and news items are
  written to `/var/lib/lumaglass/cache` and drawn at once on a cold start,
  then refreshed; a reading older than 6 hours is not shown, and failed
  fetches retry after 2, 10 and 30 minutes.
- App library: hold OK for Move to start/left/right/end, Hide and
  Uninstall. Uninstall is offered only with positive evidence the app is
  user-installed (under `/media/developer/apps` or `/media/cryptofs/apps`,
  not a `com.webos.`/`com.palm.`/`com.lge.` id, never LumaShell, Home or the
  Homebrew Channel).
- Back on the dock row jumps to its first tile.
- Wallpaper slideshow from a USB drive or `/media/developer`, with interval
  and shuffle; pictures over 8 MB or 25 megapixels are skipped with a reason.

## Reference: other webOS projects

Survey of the GitHub and r/webos homebrew projects from 2025-26. Phase in
brackets.

Rendering and measurement (plx-native, liquid-glass launcher):

- Blur cost follows the merged blurred area, not the number of panels: on
  plx-native's webOS 4.5 set 60 fps held under about 300k blurred pixels and
  fell to 24 fps full screen, and two panels far apart cost more than two side
  by side. Glass stays grouped; the budget is re-measured on the C4 [1].
- Each presented frame carries a fixed compositor charge (23-26 % of
  compositor time there, more than the whole app). Anything with a clock or
  animation, including the screensaver and ambient overlays, presents only
  when something changes [1].
- The GPU profiler read 45 fps on a 60 fps run; frame-rate claims come from
  unprofiled runs that count presented frames [1].
- Focus: the highlight moves at once; lift and scale animate only after focus
  rests 150 ms, and further moves cancel the pending animation. Animating
  glass per key press took that launcher from 16.8 ms to 127 ms mean frame
  time [1].

Input (rawin-launcher, HomeBack):

- OK acts on release, not press: acting on press lets the release reach the
  app underneath, which can launch a second app. Hold OK (700 ms) is the
  secondary action [1].
- The key filter fails open: a key is swallowed only while LumaHome is
  answering, so a hung LumaHome never traps the remote. Holding Home (650 ms)
  opens LG's Home as a manual escape, beside the heartbeat fallback [1].
- Magic Remote pointer off is `settingsservice` `general.remotePointer` ("on"
  on this set); no input injection needed.

Home and inputs:

- Live HDMI preview on the Inputs row (webos-nxe): a muted
  `service/webos-external` video only after focus rests on a connected port,
  torn down on the next move, so no video pipeline is built while scrolling.
  `getAllInputStatus` reports presence as `activate` on webOS 10 [3].
- Favourites: defaults written once, so an update never reorders the saved
  list (rawin). Per-app rename, recolour and custom icon (webos-23-custom-home)
  [3].
- Dynamic tint from the wallpaper: sample at 32x18, bin each channel into 8
  levels, skip near-black, take the most common bin; a newer wallpaper cancels
  a running sample (liquid-glass launcher) [1].
- Hero row of trending titles filtered to installed apps, OK opening the app
  (lglow; needs a TMDB key) [7, optional].
- Trial deploys (webos-home): file hashes checked before each bind mount, and
  a new Home build rolls back after 120 s unless confirmed. Used when the Home
  stub is productionised [1].

Screensaver [8]:

- LG's screensaver is not a foreground app; `tvpower/power/getPowerState`
  reports `"Screen Saver"` and `turnOnScreen` ends it (lumen-webos).
- `com.webos.app.screensaver` on this set is a Flutter bundle, so the QML
  bind-mount of webosbrew/custom-screensaver does not apply; the replacement
  is drawn in the compositor on that state.
- Burn-in rules (tv-tools, zzeppieri): mostly black, moving elements, scenes
  45-75 s with 4 s black fades, dim to 60 % over an hour, a clock that drifts
  to a new spot every 60 s; standby after a set number of hours.
- Art mode: public-domain paintings with mattes and frames (Lumen Gallery).

Receiver OSD [4]: receiver values older than 6 s without a successful read are
hidden rather than shown stale (webos-av-overlay).

Platform findings:

- `libvtcapture` has one owner: a second `vtCapture_init` fails with code 11
  (scaler busy), so the ambient histogram and any frame capture cannot run
  together (lg-hue-sync). That project's bridge client accepts only Hue's own
  certificates, so it would not talk to Bifrost.
- LG Home can be restored from a CRIU snapshot that ignores changed files; a
  stale one is dropped by touching `invalid_img` in its checkpoint directory.
  On this set `/mnt/lg/cmn_data/checkpoint` holds only `inputcommon`.
- HbbTV is already off (`option.hbbTV`).
- LG hard-codes public DNS servers and DNS-over-TLS, so a hosts-file blocker
  is incomplete without redirecting DNS; that redirect is a network change and
  Nitin's step. If blocking stops LG's time sync, the clock is set from the
  HTTP `Date` of two agreeing sites.

Not taken: locking the SSAP port 3001 to localhost (Home Assistant controls
the set through it), neutralising the remote microphone (voice uses it),
lginputhook's admin server (LAN port with path traversal), self-updaters, and
webos-mcp (raw control with no on-TV permissions; LumaShell's own MCP server
above replaces it).

## Phases

1. Foundation: component kit, tokens, Manrope everywhere including the web
   theme, startup warm-up, frame-probe harness, a registry of every surface's
   state and fallback, the native helper, the disk cache, and LumaHome in
   LG's Home's place (Home stub, see Glasshouse).
2. Notifications: toasts, alerts, PIN prompt, input popups.
3. Quick panel, Settings, and AI access (MCP server, permissions, prompt).
4. Input picker, the receiver-fed volume and mute OSD, and ambient light.
5. Launch splash, spinners, boot and power-off logos, context menu, on-screen
   remote.
6. Restyles in other processes: Live TV banners, keyboard, search and voice,
   the shared web-app theme.
7. Removal: nudges, ads and store promotions off; LG's background services
   off through Glasshouse (below); Apps tile to the own grid; Notification
   Centre to the own drawer.
8. Trim background preloads, replace the
   screensaver. Research first, under the app-manager constraint below.
9. Plugins: the broker on LumaShow's plugin API, TV drawing of cards, tiles,
   settings pages and notifications, and Home's widgets moved to plugins.

## Glasshouse

Glasshouse (rorygallagher2024/lg-webos-dashboard) is installed on the set: a
Node server (`/var/lib/tvweb`, about 34 MB resident) that bridges the TV to
Home Assistant over MQTT and holds LG's ad and telemetry hosts blocked with a
bind-mounted `/etc/hosts`. LumaShell coexists with it and does not duplicate
what it already does.

- Background services. Glasshouse masks LG daemons under
  `/run/systemd/transient` and holds them down from a boot hook. Running now
  and switchable there: `uploadd`, `rdxd`, `contentminer`, `nudge`,
  `remotelogger`. Phase 7 switches them off through Glasshouse rather than a
  second mechanism; `nudge.service` off stops nudges at the source.
- App manager restarts. Swapping the screensaver's runtime (Flutter to QML on
  webOS 10) or hiding system apps through `appinfo.json` bind-mounts needs SAM
  restarted, and on webOS 10 and 11 that restart has been followed by lost
  picture, lost ARC sound and dead HDMI-CEC until a power cut (Glasshouse
  #366). This set sends sound to the Denon over eARC, so LumaShell never
  restarts SAM: a replacement screensaver either lands before SAM first starts
  (the early boot hook, if it runs first) or is drawn by the compositor.
  System apps are hidden in LumaShell's own launcher, not through
  `appinfo.json`.
- OLED care. The luna calls Glasshouse uses are a ready source for an OLED
  care screen in the curated settings: `panelcontroller/getPanelUsageTime`,
  `tv.display/getClearPanelNoiseStatus` and `requestClearPanelNoise` (Pixel
  Refresher), `oledepl/getGlobalStressReduction` and `getTemporalPeakControl`,
  `tv.systemproperty` `OledGSR`/`OledTPC`.
- Game Optimizer. Its per-input settings (genre, prevent input delay, VRR,
  FreeSync, ALLM, black stabiliser) and the live VRR refresh readout are
  candidates for a quick-panel game card.
- Screensaver designs. Its QML screensavers (clock, starfield, bokeh) keep
  every element drifting to avoid retention; LumaShell's screensaver follows
  the same rule.
- Version on the set predates Glasshouse Home and Remote keys (no
  `home.json`, no `glasshouse.remoteKeys`). Both hook what LumaShell owns: the
  Home key and the first slot of the compositor's key-filter chain. Neither is
  switched on while LumaShell runs; an update of Glasshouse is checked for
  that.
- Key-filter writes: writing `com.webos.surfacemanager.keyFilters` reloads
  every filter and reruns LG's `init()`, which in Game mode opens the Game
  Dashboard. Glasshouse keeps one fixed filter file in the chain and passes
  its settings through a configd value the filter subscribes to. LumaShell's
  filter does the same and is written to the chain only when absent.
- Apps kept ready (phase 8): preloads are configd
  `com.webos.service.preloadmanager.supportAppList`; on webOS 10 the preload
  manager forgets the stored value at every switch-on, so `setPreloadPolicy`
  is sent again at each wake. Glasshouse already does this; LumaShell uses it.
  On the set: Netflix, YouTube, Prime Video, the browser and LG Channels are
  enabled.
- Retiring LG's Home: tested on the set on 2026-10-22 (webOS 10.2.1). A web
  stub with `appCategory: ["home"]` and `visible: false`, bind-mounted over
  `/usr/palm/applications/com.webos.app.home`; `blockSystemApp` then
  `releaseBlockSystemApp` made SAM report the stub's type within 0.5 s, with
  `blockedSystemAppList/USA.json` byte-identical afterwards and no SAM
  restart. Killing LG's Flutter process left the stub in front 3 s later and
  LumaHome drawing over it. Passed: Home key from YouTube, closing the last
  app, standby and wake, remote focus in LumaHome, volume to the AVR over
  eARC, AVR-S760H still listed on HDMI 2. Home's process went from 66-88 MB
  (Flutter) to 26-29 MB (one WebAppMgr renderer). Reverted by unmounting, the
  same block and release, and WebAppMgr `killApp`; LG's Home was back in 2 s.
  Moves into phase 1, with a heartbeat that gives LG's Home back if
  LumaHome stops drawing, a boot hook that mounts before SAM first starts
  Home, and LG's `homeAutoLaunch` held off while it is in place.
- Recent apps: `com.webos.service.recent/listRecents` with snapshots, closing
  with `closeByAppId` (native) or WebAppMgr `killApp` (web) before
  `removeRecent`, since removing the card alone leaves the app running on
  webOS 10. Back on Home opens it.
- Picture details for the input picker and quick panel: the HDMI signal
  (resolution, refresh, HDR10/HLG/Dolby Vision, VRR, ALLM) and the picture
  mode LG keeps for that input and dynamic range.
- Last opened ordering for rows, and a "what was last on" card on Home.

## Safety

- Each surface has its own switch and falls back to LG's; `lumaglass off`
  reverts everything.
- Boot verifies every redirect and restores LG's entry for any that will not
  load; the firmware fingerprint check catches LG rewriting the underlying
  files.
- PIN prompt, modal alerts, input switching and power controls get scripted
  tests before cutover. Picture Mode stays FILMMAKER MODE throughout.

## Open decisions

- Live TV usage, which sets how far the channel banner and guide go.
- AI access transport: the TV's own LAN listener (recommended, on only while
  switched on with the remote) or a connection out to HomeLabber, whose
  Face ID gate would then carry the approvals.
- Background preloads (YouTube, Netflix: about 200 MB) and whether phase 8 is
  in scope.
- Curated settings list and layout.
- Home wallpaper motion: idle Home redraws at about 36 fps because the motion
  layer runs at 30 fps. Options: 60 fps, slower (about 10 fps), or unchanged.
- Lucent v2 focus cue: bright lower edge or quieter; depth strength in dark.
- Rename of internal names (repo, app id `org.nphil.lumaglass`,
  `/var/lib/lumaglass`) to LumaShell, done once during phase 1.
