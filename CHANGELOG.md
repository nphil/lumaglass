# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
