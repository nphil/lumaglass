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

## Phases

1. Foundation: component kit, tokens, Manrope everywhere including the web
   theme, startup warm-up, frame-probe harness, a registry of every surface's
   state and fallback, the native helper, the disk cache.
2. Notifications: toasts, alerts, PIN prompt, input popups.
3. Quick panel and curated settings.
4. Input picker and the receiver-fed volume and mute OSD.
5. Launch splash, spinners, boot and power-off logos, context menu, on-screen
   remote.
6. Restyles in other processes: Live TV banners, keyboard, search and voice,
   the shared web-app theme.
7. Removal: nudges, ads and store promotions off; Apps tile to the own grid;
   Notification Centre to the own drawer.
8. Retire LG's Flutter Home, trim background preloads, replace the
   screensaver. Research first.

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
