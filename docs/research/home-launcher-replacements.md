# Home launcher replacements on rooted webOS: research

Study of existing home-screen replacements for rooted LG webOS TVs, to inform a
custom launcher targeting stability, locked 60 fps, zero functional regression,
and an extensible theme/widget engine. Target set: LG OLED, webOS 25
(platform webOS TV 10.2.1), rooted with the Homebrew Channel.

Claims marked [INFERENCE] were not observed directly. Everything else is cited.

---

## 1. Landscape

| Project | Approach | UI tech | Evidenced on | State |
| :--- | :--- | :--- | :--- | :--- |
| [PlainHome](https://github.com/int21asm/plainhome-webos) (int21asm) | Poll `/dev/input/event*`, launch over stock home | Plain HTML/JS, ES5 | webOS 10.3.1 (OLED77B36LA) | Active, v0.1.40, in webosbrew apps-repo ([PR #248](https://github.com/webosbrew/apps-repo/pull/248)) |
| [HomeBack](https://github.com/angelcode1/webos-HomeBack) (angelcode1) | Native input hook (ezinject) suppresses HOME at source; floating overlay ribbon | React + MobX + TS, SCSS | webOS 10.0.0 (OLED42C5PSA, fw 33.00.71) | Active, webOS 6+ |
| [webos-custom-home](https://github.com/zzeppieri/webos-custom-home) (zzeppieri) | Poll + launch over; separate eARC guard service | Vite + React + TS + Tailwind v4 + Framer Motion | webOS 24 (Rockhopper 9.2.1) | Active, v0.4.x |
| [webos-custom-home](https://github.com/evaniaagential327/webos-custom-home) (evaniaagential327) | Poll + launch over | React + TS + Vite + Tailwind | Unspecified | v1.4 |
| [webos10-homescreen-customization](https://github.com/mareklarek/webos10-homescreen-customization) (mareklarek; [fork](https://github.com/rustyd0g/webos10-homescreen-customization)) | Bind-mount edited Flutter *assets* over the stock home | Shell + XML edits | webOS 10.2.2 | Asset-only, not a launcher |
| [webos-custom-home-screen](https://github.com/farkmarnum/webos-custom-home-screen) (farkmarnum) | Shell overlay, non-persistent | Shell | — | Minimal |
| [webos-launch-home](https://github.com/gprot42/webos-launch-home) (gprot42) | Launcher | — | LG C4 | [Issue #2](https://github.com/gprot42/webos-launch-home/issues/2): "quite laggy … especially to scroll through menus" |
| [webosbrew-autostart](https://github.com/webosbrew/webosbrew-autostart) | Register as the "last input" so the TV boots into the app; bind-mount over `/var/lib/eim` | — | webOS 3.x only | Historical |

Supporting infrastructure:

| Project | Role |
| :--- | :--- |
| [lginputhook](https://github.com/Simon34545/lginputhook) (Simon34545, BSD-3) | Public LG Input Hook v1.4.0: remote-button remapper built on ezinject. HomeBack bundles a community v1.5.0 binary whose source is not public (SHA-256 only). |
| [ezinject](https://github.com/smx-smx/ezinject) (smx-smx) | ptrace-based `.so` injector for ARMv7/aarch64; successor to libhooker. Needs root. |
| [disable-lg-magic-remote](https://github.com/bciuca/disable-lg-magic-remote) (bciuca) | Reference hook: no-ops the pointer functions in `lginput2`, leaves `lginput_uinput_send_button` intact. Documents boot-time re-injection when `lginput2` respawns. |
| [Homebrew Channel](https://github.com/webosbrew/webos-homebrew-channel) | Root elevation, `init.d` runner, failsafe, telnet/SSH. |

No project in the webosbrew apps repository is a home replacement; PlainHome is the only launcher submitted there.

---

## 2. Three ways to take over Home

### 2a. Asset overlay on the stock Flutter home (webOS 10 only)

The stock home on webOS 10/25 is a native Flutter app: Dart AOT in
`/usr/palm/applications/com.webos.app.home/lib/libapp.so`, layout and assets in
`…/data/flutter_assets/assets/` (`home.xml`, `home_layoutShelfView.xml`,
`i18n/*.json`, `images/{hd,2k,4k}/`). The rootfs is read-only and signed, so the
technique is: copy the assets dir to `/tmp`, replace the `i18n` symlink with a
real directory, edit, `mount --bind` over the original, `pkill -f
com.webos.app.home`. A `/var/lib/webosbrew/init.d/49-custom-homescreen` symlink
re-applies it each boot.

What it can change: remove `recommendedShelf` (531 px content strip) and
`qcardList`; shrink `globalline` to 0×0 (deleting the item black-screens the
home); swap hero images; edit strings. What it cannot: icon size (hard-coded in
`libapp.so`), any rendering logic. Recovery is a reboot; the mount does not
persist. Source: mareklarek README and `apply.sh`.

Notable: `home.xml` declares `itemWidth="3840"`, i.e. the native Flutter home
lays out at 3840 wide, unlike WAM web apps which LG caps at 1920×1080
([appinfo.json reference](https://webostv.developer.lge.com/develop/references/appinfo-json):
"webOS TV does not support UHD resolution for web apps"). Whether the native
home actually composites at 4K on the graphics plane is unverified.
[INFERENCE: probable.] This is the one place a native app could beat a web
app on resolution; see §8.

This is theming, not replacing. It is the safest option and the least capable.

### 2b. Poll the input node and launch over the stock home (PlainHome, both webos-custom-home forks)

A Node.js helper started from `init.d` polls `/dev/input/event*` every 100 ms
without grabbing the device, recognises HOME (key code **773** on the Magic
Remote; varies by model), debounces, then calls
`luna-send … luna://com.webos.applicationManager/launch '{"id":"<launcher>"}'`.
For boot and wake it subscribes to
`luna://com.webos.service.tvpower/power/getPowerState` and launches on the
`Suspend→Active` transition with bounded retries
(PlainHome `service/service.js` lines 105–180).

Consequence, stated in PlainHome's own README: the watcher "does not grab the
input device, suppress the key, patch lginput2, or inject code into an LG
process. Consequently, LG's native Home action may appear briefly before
PlainHome opens." **The stock home flashes first.** This approach cannot meet
the "never see LG home" requirement.

Permissions: a rooted launcher writes its own Luna ACG file, e.g.
`/var/luna-service2-dev/client-permissions.d/<appid>.json` granting `public`,
`applications.launch`, `applications.internal` (PlainHome `autostart.sh`).

### 2c. Native input hook: suppress HOME at the source (HomeBack)

Remote input path on webOS:

```
IR/BT remote → lginput2 (com.webos.service.mrcu)
             → lginput_uinput_send_button()  ──►  /dev/uinput
MICOM MCU    → micomservice → MICOM_FuncWriteKeyEvent() ──►  /dev/uinput
                                          → /dev/input/eventN → SAM/LSM → launch com.webos.app.home
```

ezinject ptrace-attaches to `lginput2` and `micomservice` and loads
`libinputhookpp.so`, which hooks `lginput_uinput_send_button` and
`MICOM_FuncWriteKeyEvent`. Per key the hook can **pass** (log and forward),
**ignore** (return early: the event never reaches `/dev/uinput`, so SAM never
sees HOME and the stock home never launches), or **replace** (rewrite the code).
The hook writes every event to a log the helper tails
(`/tmp/homeback-events-<pid>.log`; patterns in
`packages/service/src/remote-press-state-machine.ts` lines 15–17), and a state
machine distinguishes short from long press with a 650 ms default threshold
(lines 84–142). Native key config: `/home/root/.config/lginputhook/keybinds.json`
(written by `NativeConfigWriter`, `remote-input.ts` lines 93–105); HomeBack's
own mapping file: `/home/root/.config/homeback/remote-buttons.json`.

Default HOME mapping (REMOTE-BUTTONS.md): short → `launch com.homebrew.homeback`
with `intent: homeback:show`; long (>650 ms) → `launch com.webos.app.home`. So
the stock home is still reachable by design, and an `ignore` mapping removes it
entirely.

**This is the only mechanism found that satisfies "the LG home never draws."**

Safety properties observed in HomeBack:
- Injection happens ~30 s after boot when `lginput2` is up; the `init.d` script
  retries `luna://com.homebrew.homeback.service/remote/start` for up to 120 s
  (`bootstrap.ts` lines 71–76).
- `timedMappingsArmed` is fail-open: native ignores are armed only while the
  helper has a healthy log tailer and `nativeOwnershipVerified`; otherwise the
  entries are disarmed so buttons pass through "rather than becoming dead
  system-wide" (`remote-input.ts` lines 296–300).
- The UI is intentionally never force-launched at boot; the ribbon appears on
  HOME only, to avoid an "unresponsive floating-app bug on early surface-stack
  startup" (IMPLEMENTATION-NOTES.md).
- Re-injection if the daemon respawns (also in bciuca's project).

Risk: if the hooked daemon crashes, the remote goes dead except the power
button (bciuca README). Recovery is SSH/telnet, remove the `init.d` hook,
reboot. The Homebrew Channel's failsafe flag
(`/var/luna/preferences/webosbrew_failsafe`, cleared ~10 s after `init.d`
completes) re-enables emergency telnet if boot crashes.

Supply chain: HomeBack ships a v1.5.0 hook binary of unknown authorship
(hashes only). Public source is v1.4.0. A build that depends on this should
compile the hook from source.

### 2d. Wholesale replacement of `com.webos.app.home`

No documented success on webOS 9 or 10. Bind-mounting a web app over the
Flutter app's directory would require SAM to accept a different `appinfo.json`
type under the same ID and satisfy whatever the launch contract for the native
home is; nothing found tests this, and the asset-overlay authors deliberately
kept `libapp.so`. Not a viable path without original research on the set.

---

## 3. What the stock home owns, and what is separable

Evidence across all projects: the stock home is a presentation layer.
Nothing found shows it as load-bearing for audio routing, CEC, notifications,
input switching, voice, or power.

| Responsibility | Where it lives | Replacement launcher delegates via |
| :--- | :--- | :--- |
| App list and launch | SAM | `com.webos.applicationManager/listLaunchPoints`, `/launch`, `/closeByAppId`, `/getForegroundAppInfo` |
| HDMI inputs | EIM | `/var/lib/eim/eim_device_db.json` (PlainHome reads `appId` `com.webos.app.hdmi[1-4]`, `bPlugIn`, `szUrcuLabel`); switch by launching `com.webos.app.hdmiN` |
| Input picker UI | Surface manager | `com.webos.surfacemanager/showInputPicker` (used by HA integrations) |
| Notifications/toasts | `com.webos.notification` | `createToast` (this workspace's `tvweb.js` already uses it, with `com.webos.app.home` as the attributed source) |
| Sound output | `com.webos.service.audio` | `getSoundOutput` (subscribable), `setSoundOutput`; `com.webos.settingsservice` `soundOutput`, `eArcSupport` |
| CEC | `com.webos.service.cec` | Protocol-level; not touched by any launcher |
| Power/wake | `com.webos.service.tvpower/power/getPowerState` | Subscribe; used by every launcher for boot/wake |
| Physical key emit | `micomservice/sendKeycode` | HomeBack's keypad sends 0–9 and R/G/Y/B this way; note the Magic Remote cursor hides on a MICOM send (compositor behaviour, unfixable) |
| Quick settings, voice, LG Channels, AirPlay/HomeKit, Bluetooth | Separate system apps/services | Untouched by every launcher; no regression reports found. Whether the quick-settings panel is reachable while a custom launcher is foreground is unverified. |
| Screensaver | `com.webos.app.screensaver` | zzeppieri replaces it with an in-app ambient mode after 60 s; the rest leave it alone |

---

## 4. Regressions actually observed

| What | Cause | Status |
| :--- | :--- | :--- |
| **eARC/ARC receiver comes up desynced after cold boot or standby wake** — TV shows the receiver as output, nothing plays, user toggles eARC by hand | Pre-existing LG firmware behaviour, not launcher-caused. Sonos community reports the same on stock firmware after an April 2024 update ([thread](https://en.community.sonos.com/home-theater-229129/problem-with-arc-since-lg-webos-update-6891973)). PlainHome and HomeBack have no eARC reports. The stock home performs no eARC renegotiation. [INFERENCE: a launcher that autostarts at boot does not cause it, but neither does anything paper over it.] | zzeppieri's opt-in "eARC edition" (`tv-install-earc.sh`): web side subscribes `com.webos.service.audio/getSoundOutput` and calls `setSoundOutput` when the value drifts (boot window: 2 s retries for 60 s, then event-driven); native side, ~10 s after boot and after wake, reads `soundOutput` + `eArcSupport` from `com.webos.settingsservice/getSystemSettings` and, if `soundOutput == external_arc`, toggles `eArcSupport` off, waits 2 s, on — forcing a fresh HDMI handshake. Cost: ~2 s audio blip per power-on. |
| **Home key code varies by remote/model** | 773 hard-coded in PlainHome; zzeppieri reads `HOME_CODE` from config | Must be learned per set, not assumed. |
| **Firmware update resets the takeover** | Update rewrites the rootfs and may reset SAM state; bind-mounts and hooks need re-applying | Both webos-custom-home READMEs say so. The `init.d` hook survives (it lives in `/var/lib`), so re-application on next boot is automatic unless the update changes the hooked binaries. Already documented for this workspace's screensaver. |
| **Menu scroll lag** | webos-launch-home on a C4 ([#2](https://github.com/gprot42/webos-launch-home/issues/2)) | Rendering discipline, §5. |
| **Floating app unresponsive if launched too early at boot** | HomeBack IMPLEMENTATION-NOTES | Do not force-launch the UI before the surface stack is up. |
| **Dead remote if the hooked daemon crashes** | Hook approach only | Fail-open disarm plus SSH recovery. |
| **webOS 26: Homebrew Channel cannot write apps after update** ([#234](https://github.com/webosbrew/webos-homebrew-channel/issues/234)) | Unrelated to launchers; a warning about future firmware | Block updates on the set if the launcher matters. |

Confirmed unaffected by every project surveyed: HDMI-CEC/SimpLink, input
switching, notifications, voice, AirPlay/HomeKit/Chromecast, Bluetooth audio,
LG Channels, firmware updates themselves.

---

## 5. Platform constraints for the UI

**Engine.** LG's [web engine table](https://webostv.developer.lge.com/develop/specifications/web-api-and-web-engine):
webOS 23 → Chromium 94, webOS 24 → 108, **webOS 25 → 120**. PlainHome's
webosbrew compatibility check reports Chromium 120 on 10.3.1. So: WebGL2,
WASM, Workers, CSS containment and `content-visibility` are available; WebGPU
is not. `backdrop-filter` and OffscreenCanvas are unverified on the TV build.

**Graphics plane.** 1920×1080 for web apps, upscaled by the TV; the video
plane is separate and full 4K. rAF ticks at the UI plane's vsync; 60 Hz is the
working assumption (unmeasured on this set, see §8). Locked 60 is the target.

**Memory.** LG's guidance is ~250 MB per app; WAM kills silently over the limit
([forum](https://forum.webostv.developer.lge.com/t/this-app-will-now-restart-to-free-up-memory/5605)).
`requiredMemory` in appinfo is a launch minimum, not a ceiling.

**Lifecycle** ([app lifecycle](https://webostv.developer.lge.com/develop/getting-started/app-lifecycle)):
`webkitvisibilitychange` on background/foreground; `webOSRelaunch` when an
already-running app is launched again, delivered only with
`"handlesRelaunch": true` (the app then calls `PalmSystem.activate()` when
ready). Other relevant appinfo keys: `disableBackHistoryAPI` (take the Back key
yourself), `splashBackground`, `transparent`, `defaultWindowType`
(`"floating"` is how HomeBack overlays a ribbon without leaving the current
app), `supportQuickStart`, `resolution`.

**Input.** Key codes delivered to web apps: arrows 37–40, OK 13, Back 461, Red
403, Green 404, Yellow 405, Blue 406. HOME is *not* delivered to apps; it is
consumed below WAM, which is the whole reason for §2. Magic Remote pointer mode
and 5-way mode coexist: pressing an arrow leaves pointer mode, shaking the
remote returns; `cursorStateChange` reports visibility. Every launcher handles
both, with plain `.focus()` management and no Spotlight framework; HomeBack's
ribbon auto-hides after 3 s of inactivity.

**Rendering, grounded in Jellyfin webOS and launcher reports.** Do: animate
`transform` and `opacity` only, `contain: layout style paint` per widget,
`content-visibility: auto` for offscreen rows, rAF-batched DOM writes, images
pre-sized to their on-screen pixels. Don't: `box-shadow`, `filter`/`blur`,
`backdrop-filter`, more than a few dozen simultaneously animating layers,
synchronous layout reads in loops, unbounded lists without virtualisation.
Zzeppieri needed Lightning CSS to downlevel Tailwind v4 `oklch()` and
`color-mix()` for Chromium 108; Chromium 120 supports both, but the point
stands: target the exact engine.

**Instant show.** Every launcher gets "instant" Home by being already resident
and merely foregrounded. Cold WAM start is measured in seconds
([forum](https://forum.webostv.developer.lge.com/t/not-able-to-reduce-my-lg-application-s-launch-time-i-e-23-24-secs-in-4x-webos-tv-version-to-10-12-secs-like-it-is-in-6x-7x/6173)),
so residency is non-negotiable.

**init.d contract.** `/var/lib/webosbrew/init.d/`, run by BusyBox `run-parts`
in name order; names match `[0-9a-zA-Z_-]+`, no dots; runs before the failsafe
flag clears; non-zero exit is logged, not fatal; detach anything long-running.
This workspace's `50-tvweb` already follows it.

---

## 6. Theme and plugin engine precedents

| Precedent | Load | Isolation | Theme | Lesson |
| :--- | :--- | :--- | :--- | :--- |
| [Home Assistant custom cards](https://developers.home-assistant.io/docs/frontend/custom-ui/custom-card/) | ES module → `customElements.define` | None; Shadow DOM for styles only | Host CSS variables | Simple, fast, trust-based; a bad card can take the page down |
| [Kodi skins](https://kodi.wiki/view/Skinning_Manual) | `addon.xml` manifest, per-resolution dirs, texture archives | In-process | Texture cascade: theme → default | Manifest + fallback cascade is the durable pattern for TV UIs |
| [VS Code webviews](https://code.visualstudio.com/api/extension-guides/webview) | Sandboxed iframe + `postMessage` | Strong | Injected CSS | Production-grade untrusted UI hosting; every call is async |
| [Grafana panels](https://grafana.com/docs/grafana/latest/developers/plugins/) | `plugin.json` + built bundle | None; signing | Theme context/hook | Versioned manifest and a typed host API |
| Figma plugins | Realms/SES-style sealed scope | Strong | — | Needs Realms/SES; availability on Chromium 120 unverified |
| [Obsidian](https://obsidian.md/help/plugin-security) | In-process, no Workers | None | CSS snippets | Convenient and risky; shows why Worker isolation matters for perf |
| [Jellyfin CSS themes](https://jellyfin.org/docs/general/clients/css-customization/) | Injected CSS | n/a | CSS custom properties | Code-free themes are safe and portable |
| Projectivy (Android TV) | Plugins are APKs found via package manager | Process | Provider interfaces | Discovery via installed-package scan mirrors scanning a plugins dir |

Recommended model for a single WAM page:
- **Themes are data, not code**: a JSON token manifest plus an optional CSS file
  that only sets custom properties; fallback cascade theme → default → built-in.
- **First-party widgets**: custom elements with Shadow DOM and `contain`; direct
  host state access; the fast path.
- **Third-party widgets**: sandboxed iframes with a `postMessage` protocol and a
  capability manifest; batched at ≤1 update per frame; never for high-frequency
  animation.
- **Logic off the main thread**: Workers with a host-side deadline and
  `terminate()` on overrun.
- **Focus contract**: the host owns arrow keys and emits `nav` events; a widget
  reports its focusable rectangles and receives enter/leave; focus ring is a
  2 px `outline` with 3:1 contrast, never `box-shadow`.
- **Render budget**: per-widget frame accounting; offscreen widgets get
  `content-visibility: auto` and paused timers.

---

## 7. Implications for the build

1. **Use the native input hook, compiled from source.** It is the only route
   to "LG home never draws." Keep HomeBack's two safety ideas: fail-open
   disarm when native ownership cannot be verified, and re-injection when the
   daemon respawns. Keep a long-press (or other) escape to
   `com.webos.app.home` at least during development.
2. **Never kill or replace `com.webos.app.home`.** Leave it resident. There is
   no evidence it is load-bearing, but there is also no evidence it is safe to
   remove, and the asset-overlay authors kept the binary for a reason.
3. **Resident, relaunch-aware web app**: `handlesRelaunch: true`,
   `disableBackHistoryAPI: true`, launched once after the surface stack is up
   (not at `init.d` time), foregrounded on HOME. Decide up front between a
   fullscreen card app (a true home) and a floating overlay (HomeBack); the
   former is what "replace the home" means.
4. **Delegate every system function** per §3 rather than reimplement it; for
   input picker, notifications, and quick settings, open the stock component.
5. **Ship the eARC guard as an opt-in module**, implemented exactly as
   zzeppieri's (subscribe `getSoundOutput`, re-assert; toggle `eArcSupport`
   ~10 s after boot/wake). It fixes a firmware bug the launcher inherits, and
   the blip is a real cost.
6. **Learn the HOME key code on the set**; do not hard-code 773.
7. **Rendering discipline from §5 is the whole 60 fps story**; no framework
   choice substitutes for it. Plain DOM with compositor-only animation is what
   every smooth launcher here does.
8. **Recovery path first**: SSH access, an `init.d` kill switch, and a
   documented "remove hook, reboot" procedure before the hook is ever armed.
9. **Firmware updates**: pin or block them on this set; a hook against
   `lginput2` symbols is the most update-fragile piece.

---

## 8. To verify on the set before designing

- rAF rate under WAM (60 vs 120) and whether the graphics plane is 1080p for
  web apps on this firmware; whether the Flutter home composites at 3840 wide.
- The HOME key code(s) for the Magic Remote and IR remote; which daemon
  (`lginput2` vs `micomservice`) carries each; symbol availability of
  `lginput_uinput_send_button` and `MICOM_FuncWriteKeyEvent` on 10.2.1; SoC
  arch (aarch64 expected).
- Whether the hook survives standby/wake without re-injection.
- Whether the quick-settings panel and input picker open normally while a
  custom fullscreen app is foreground.
- eARC state across cold boot, wake, and app launch with the current stock
  setup, to establish a baseline before any launcher exists.
- `backdrop-filter`, OffscreenCanvas, and Realms support on Chromium 120 TV.
- Memory ceiling in practice for a resident app on this set.

---

## Sources

Launchers: PlainHome (`app/app.js`, `service/service.js`, `service/autostart.sh`,
`app/input-reader.js`, README); HomeBack (`packages/service/src/{bootstrap,
remote-input, remote-press-state-machine, index}.ts`, `REMOTE-BUTTONS.md`,
`docs/history/IMPLEMENTATION-NOTES.md`, issues #21 #28 #29 #43);
zzeppieri/webos-custom-home (`README.md`, `src/service/luna.ts`,
`src/service/service.js`, `tv-install-earc.sh`); evaniaagential327/webos-custom-home
README; mareklarek/webos10-homescreen-customization README and `apply.sh`;
gprot42/webos-launch-home #2.
Hooks: Simon34545/lginputhook; smx-smx/ezinject; bciuca/disable-lg-magic-remote.
Platform: webosbrew.org (filesystem overlays, glossary, rooting);
webosbrew/webos-homebrew-channel `services/startup.sh`, issues #96 #234;
webostv.developer.lge.com (appinfo.json, app resolution, web engine, Magic
Remote, app lifecycle); webosose.org LS2 API references (applicationmanager,
notification, sleep); jellyfin/jellyfin-webos issues #93 #170 #195 #248.
