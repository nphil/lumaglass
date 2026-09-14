# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.5] - 2026-09-14

### Fixed

- The set now stays in active standby after power-off, so a later power-on
  is instant with the mod already on screen. It never did before: every
  power-off was a hidden reboot, because the crash report the compositor
  restart provokes (inputcommon, `QFontDatabase::removeAllApplicationFonts`)
  was never actually removed. `disarm_restart_crashes` read the names back
  from `ls`, which word-split them on spaces and printed the 0x02 bytes rdxd
  uses in place of `/` as `?`; `rm -f` on those names was a no-op that still
  counted as a success, so "disarmed 9" meant nothing. faultmanager then
  answered the suspend request with `rebootToSuspend`, and tvpowerd rebooted
  the set ~6s after it had entered active standby. The sweep now uses
  pathname expansion, which returns the raw bytes, and runs a second time
  once Home is back on the panel, since the crash lands ~3s after the
  restart and can miss the first pass.

  Measured: three power-off / wake cycles of 150s each with no reboot,
  uptime carrying across, and the same compositor still running.

### Added

- An "Instant on" toggle in the app, `standby warm|cold` in the CLI. Warm
  turns Quick Start+ on and `enableSDDP` off, remembering the previous SDDP
  value; cold turns Quick Start+ off and restores it. The tradeoff is the
  user's: warm means an instant power-on with the mod already up, at the cost
  of higher standby draw and no Control4 discovery; cold is the lowest
  standby draw with a ~35s boot at every power-on. `enableSDDP` matters
  because `webos-sddp` crashes on the first wake from active standby on this
  firmware, and its crash report arms the same reboot at the next power-off.
  `status` reports the live mode as `standby`: `warm`, `cold`, or `system`
  (Quick Start+ on with SDDP still enabled - the stock state, which is not
  instant-on in practice).

## [0.3.4] - 2026-09-14

### Changed

- The mod now reaches the screen at boot+33s instead of boot+55-60s, and the
  boot no longer shows stock Home before switching. Two changes get there.

  The apply used to run from Homebrew Channel's `init.d` run-parts at ~33s,
  by which time Home has long since painted. It now triggers at ~12-14s from
  a PATH shim in front of `grep` for `kdump.service`, which starts at 14.2s,
  reads an `EnvironmentFile` under `/var`, and on a set without `crashkernel`
  on the kernel command line is a no-op that exits 0. The shim always execs
  the real grep, so it cannot stop that unit, and run-parts stays as the net
  in case the early apply fails.

  The restart path also slept 14s before asking for Home and 8s after.
  Measured, asking for Home immediately still put pixels on the panel at
  +12s, so both sleeps are gone. Readiness is now taken from the panel: a
  captured frame is 835 bytes while it is still blank and over 79000 once
  Home is composited, whereas the Home process, `NL_HOME_SHOWN` and
  `getForegroundAppInfo` all go true about 8s before anything is drawn.

  Restarting the compositor that early also provokes none of the stock-app
  segfaults a later restart does, so there are no crash reports to disarm.

### Fixed

- The cause of the compositor's first start ignoring the override, withdrawn
  as unexplained in 0.3.3, is that `/var` does not show the writable ext4
  subtree until `mount-readwrite.service` relocates it at 12.96s.
  `surface-manager-daemon` starts at 2.63s, so `/var/systemd/system/env` is
  not a path that exists yet and the optional read is a silent no-op - the
  file's atime is untouched across a boot, and LG's own env files for
  `ls-hubd`, `configd`, `memchute`, `tvpowerd`, `bootd` and `sam` are equally
  inert that early. One compositor restart per boot is therefore structural,
  and 13s is the floor for anything this mod can do.

  Baking the mod into the hibernation image the set resumes from
  (`snapshot resume=/dev/mmcblk0p54`) was tried and does not work: the image
  is captured at ~15s, before the 13s floor plus a compositor restart can
  complete, so it always captures the stock compositor.

- The late hook no longer applies a second time on top of the early one. It
  stands down while an early worker is running or has succeeded, and only
  takes over if that worker died with the boot still incomplete.

## [0.3.3] - 2026-09-14

### Fixed

- A boot could leave the modded Home layout with the stock compositor: no
  wallpaper, no clock, weather or news. `apply` only restarted the compositor
  when the panel already reported Active, and on a boot where the panel had not
  finished waking it skipped the restart and nothing retried, so the set ran the
  whole session on stock QML. The restart now happens whenever the running
  compositor lacks the shadow module, whatever the panel is doing; a restart
  while the panel is dark is invisible, never restarting is not

### Changed

- The claim that the compositor picks the override up on its first start is
  withdrawn. Measured across consecutive boots it takes the global
  `DefaultEnvironment` from `/etc/systemd/system.conf.d/30-webos-global.conf`
  instead of the unit's `EnvironmentFile`, although the same file applies to
  every later restart, and `var.mount` completes at 1.946s while
  `surface-manager-daemon` does not start until 2.591s - so the file was
  readable. Cause not established, and nothing depends on it any more. One
  restart per boot remains the norm; what keeps power-off immediate is clearing
  the crash reports that restart produces, not avoiding the restart

## [0.3.2] - 2026-09-14

### Fixed

- A power cut while the shadow compositor module was being written left the TV
  with a black screen on the next boot. `/var` is ext4 `data=ordered`, so the
  directory entries were committed and the file contents were not: the module
  had all 318 files present holding 212KB instead of 2030741 bytes. The
  compositor started on it, resolved nothing and presented nothing, and because
  it was running and healthy no liveness check noticed. `build_shadow` now
  syncs the contents to disk before the rename publishes them
- Shadow integrity is checked against a fingerprint of the whole tree, not just
  the one file we inject. The truncated files were never looked at, so the
  damaged module was reported as current
- `boot-bind` restarts the compositor after repairing a module the compositor
  had already loaded. Rebuilding on disk does nothing for a process that read
  the bad copy at startup

## [0.3.1] - 2026-09-14

### Fixed

- The firmware-staleness guard never fired. `stock_module_fp` used
  `find -printf`, which busybox 1.35 does not implement, and the failure was
  silent: the pipeline hashed empty input, so every fingerprint compared equal
  to every other and a replaced compositor module would have gone unnoticed.
  It now fingerprints the recursive listing

## [0.3.0] - 2026-09-14

### Changed

- The compositor no longer gets its QML from a bind mount over `/usr`. A full
  shadow copy of the `WebOSCompositor` module lives in `/var/lib/lumaglass/qml`
  with the modded file swapped in, and `QML2_IMPORT_PATH` points at it through
  `/var/systemd/system/env/surface-manager.env`, an optional environment file
  the compositor's own unit already reads. The compositor therefore starts on
  the modded QML at boot+2s. Only Home's assets are still bound

### Fixed

- Cold boot no longer shows stock Home for ~25s before the mod appears, and no
  longer restarts the compositor. A restart was previously unavoidable: the
  compositor reads QML once at startup, it starts at boot+2s, and Homebrew
  Channel's hooks cannot run before boot+20s
- Power-off is immediate again. A compositor restart makes LG's igallery
  preview segfault in `QFontDatabase::removeAllApplicationFonts` - reproducible
  on stock firmware with no mod present - and faultmanager then reports the
  crash with recovery `rebootToSuspend`, so tvpowerd answered the next power
  press with a full reboot into standby instead of switching off. Not
  restarting the compositor avoids the crash; when an interactive apply does
  have to restart it, the reports that restart produces are removed

### Added

- `boot-bind` rebuilds the shadow module when the stock one changes, so a
  firmware update cannot leave stale QML bound to new libraries, and drops the
  environment override entirely if the rebuild fails or if it finds no
  compositor running - a persistent override could otherwise repeat a failure
  on every boot
- `status` reports `live`, whether the running compositor actually has the mod,
  separately from `applied`

## [0.2.4] - 2026-09-14

### Fixed

- The boot hook no longer forces the panel on. `apply` calls `turnOnScreen`
  before relaunching Home because a compositor restart can leave the panel
  blanked; on the boot path that turned a set back on after a crash-recovery
  reboot-to-suspend. The hook now marks itself as the boot path and the panel
  is left to whatever the system decided

## [0.2.3] - 2026-09-14

### Fixed

- 0.2.2 could leave the compositor on stock QML under the modded layout: a
  black Home with only the sidebar and dock. It judged whether the compositor
  predated the binds by `/proc/<pid>`'s mtime, which on this kernel is only the
  time the `/proc` entry was last instantiated, not the process start. The
  decision now uses the kernel's own record (`/proc/<pid>/stat` field 22), in
  seconds since boot, and the bind time is recorded the same way and scoped to
  the boot id, so it cannot be confused by an unsynchronised wall clock or a
  record left by a previous boot
- The shader-failure check is anchored on a log line count taken before the
  restart again, never a timestamp: the log spans boots and its early lines
  carry an unsynchronised clock

### Changed

- 0.2.2 claimed cold boot no longer restarts the compositor. That was wrong,
  and the measurement behind it was the same bogus timestamp. The compositor
  starts at boot+2 s and Homebrew Channel's hooks run at boot+20 s, and `/etc`
  is a read-only overlay with no way to order a unit ahead of it, so a cold
  boot always takes exactly one restart. `boot-bind` stays: it makes that
  restart happen as early as the hook allows, and any later compositor start
  picks the modded QML up on its own

## [0.2.2] - 2026-09-14

### Changed

- Cold boot no longer restarts the compositor. The compositor starts about two
  seconds after Homebrew Channel's hooks, and a full apply spent ~5 s staging
  before its binds landed, so it read stock QML and had to be restarted: a
  fifteen-second black screen on every boot. The boot hook now binds the
  previous boot's verified set first, in well under a second, so the compositor
  loads the modded QML on its own first start
- `apply` is idempotent. A staged set identical to what is already live is left
  mounted rather than drained and re-bound, and the compositor is judged against
  the time that content actually went live. A no-op apply now takes about a
  second and makes no restart
- `fps` goes through `apply`. The inline version bound both QML paths, which
  are one inode, and stacked two mounts

### Added

- `boot-bind` and `boot-ok` verbs for the boot hook. `boot-bind` only mounts a
  set that a full apply has verified on this firmware, and skips itself once
  after a boot that never reported ok

## [0.2.1] - 2026-09-14

### Fixed

- Boot hook no longer holds Homebrew Channel's failsafe window open. `startup.sh`
  arms a failsafe flag, runs `run-parts`, then clears the flag ten seconds later;
  applying inline took around 45 seconds, so a set powered off in that window came
  back in failsafe mode with every root customization disabled. The hook now
  returns immediately and applies in a detached child
- `apply` only restarts the compositor when it has to. If the compositor started
  after the binds went live it already loaded the modded QML, and if the panel is
  not active the binds are left staged for its next start. Both cases previously
  cost a needless restart, one of them on the boot path
- `apply` and `revert` take a lock. A detached boot apply can now overlap a user
  launching the app, and two concurrent runs could leave the wrong number of
  mounts live

## [0.2.0] - 2026-09-14

### Added

- News card in the bottom-left corner: photo, headline and as much of the summary
  as fits, rotating every 10 seconds. Top world and US stories come from keyless
  public RSS (BBC News, falling back to The New York Times), so the widget ships
  with no API key and no quota

## [0.1.0] - 2026-09-14

### Added

- Initial release: LumaGlass homebrew app for rooted LG webOS 10 TVs
- Liquid glass compositor theme with Rose Pine color palette
- Abstract wallpaper displayed through transparent Home screen
- Decluttered home layout with refactored UI strings
- `apply` command: Install mod via bind mounts, restart services
- `revert` command: Remove mod, restore original assets, restart compositor
- `persist` command: Enable/disable state persistence across reboots
- `fps` command: Toggle compositor FPS debug overlay
- `ntfy` command: Configure ntfy.sh integration for notifications
- `status` command: Display current mod state and configuration
- `log` command: View debug logs from recent operations
- Web UI app built with Homebrew Channel integration
- Self-updating via GitHub Releases
- Custom Homebrew Channel repository support
- Non-destructive install: all changes are mount-based, easily reverted
- Tested on LG webOS 10.2.1 (32-bit ARM userspace, Rockhopper chassis)

### Technical

- Build tooling: POSIX shell scripts, no webOS SDK required
- Deployment: ar-based IPK packaging, deterministic builds
- CI/CD: GitHub Actions + Gitea mirror workflows
- Compositor QML: Custom materials and shaders for glass effect
- Home app modifications: XML layout, image overlays, localization strings
- Persistent state: `/var/lib/lumaglass/` with auto-backup of original assets
