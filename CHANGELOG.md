# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
