# LumaShell implementation plan

LumaShell (formerly LumaGlass) replaces every visible part of the LG C4's
interface with surfaces in the Lucent design language, while webOS keeps
providing tuning, inputs, playback and settings. The current Home is the
visual reference. Nothing is written to `/usr`; each surface is switched on
through a reversible hook and falls back to LG's own on failure.

Design language: `skill://design-language` (Lucent v2, TV profile). Surface
inventory snapshot of the firmware: `/data/home/lgtv/uiinv`.

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
| Settings | Web app, +93 MB while open | Curated screens in the quick panel; LG's app themed for the rest | System UI redirect + web theme |
| Settings sub-apps | Enact web apps | One shared theme | Overlay mount |
| Notification Centre | Web app | Own drawer | Launch redirect |
| Context menu, on-screen remote | Compositor QML | Rebuilt | System UI redirect |
| Recents, multi-view frames | Compositor QML | Restyled | Shadow module |
| Boot and power-off logo | Compositor QML | Own animation | System UI redirect |
| Screensaver | Flutter | Own, keeping OLED pixel shift | Research |
| Nudges, sports alarm, store promotions | Compositor QML | Off (empty view) | System UI redirect |
| Ad and content-recognition overlays | Native | Off through LG settings | Settings |

Not owned: third-party app UIs (Netflix, YouTube, PlxNative), the Magic Remote
pointer (native; image swap unverified), video.

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

A static aarch64 helper (Go, as in LumaShow) runs beside the compositor. It
holds the receiver connection and later the settings data layer. The
compositor's userspace is 32-bit and stays that way; the helper does not
change rendering cost. News and weather parsing does not justify it on its
own: measured at 0-1 ms per feed on the compositor thread.

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
   kit for the corners, Gledopto Elite GL-C-618WL (ESP32, WLED, Ethernet,
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

## Phases

1. Foundation: component kit, tokens, Manrope everywhere including the web
   theme, startup warm-up, frame-probe harness, a registry of every surface's
   state and fallback, the native helper, the disk cache, and LumaHome in
   LG's Home's place (Home stub, see Glasshouse).
2. Notifications: toasts, alerts, PIN prompt, input popups.
3. Quick panel and curated settings.
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
- Magic Remote pointer use, which adds hover states to every surface.
- Background preloads (YouTube, Netflix: about 200 MB) and whether phase 8 is
  in scope.
- Curated settings list and layout.
- Home wallpaper motion: idle Home redraws at about 36 fps because the motion
  layer runs at 30 fps. Options: 60 fps, slower (about 10 fps), or unchanged.
- Lucent v2 focus cue: bright lower edge or quieter; depth strength in dark.
- Rename of internal names (repo, app id `org.nphil.lumaglass`,
  `/var/lib/lumaglass`) to LumaShell, done once during phase 1.
