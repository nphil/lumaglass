# LumaGlass

Liquid glass home screen for rooted LG webOS TVs. Reskins the stock LG webOS 10 Home screen with a compositor-level "liquid glass" material design, generated abstract wallpaper, and a decluttered home layout.

EXPERIMENTAL - TRY AT YOUR OWN RISK!

## Features

- **Liquid glass theme**: Layered glass aesthetic with Rose Pine color palette, applied at the compositor level for seamless integration
- **Abstract wallpaper**: Generated dynamic wallpaper displayed through a transparent Home screen
- **Decluttered layout**: LG's network-loaded recommendation shelf and Q-card row are removed, which is also the single biggest responsiveness win; the hero strings are blanked so the clock and weather widgets own that space
- **Survives reboots**: an opt-in Homebrew Channel boot hook re-applies the mod after every restart. It does **not** survive a firmware update - an update replaces the system partitions, after which you re-apply from the app (one button)
- **Non-destructive**: every change is a bind mount over a read-only file plus a private copy under `/var/lib/lumaglass`. No system file is ever written, and `Revert to stock` removes all of it

## Requirements

- **LG webOS 10.2.1** (tested on 32-bit ARM userspace, aarch64 kernel; compatibility with other webOS 10 releases likely)
- **Rooted TV** with Homebrew Channel installed
- **SSH access** to the TV (enabled by default on rooted TVs)

## Installation

### Via Homebrew Channel (Custom Repository)

1. Open the **Homebrew Channel** app and press the **gear** icon to open Settings
2. Add this repository URL:
   ```
   https://raw.githubusercontent.com/nphil/lumaglass/main/repo.json
   ```
3. Go back to the app list and refresh; **LumaGlass** appears alongside the official packages
4. Select it and press **Install**. Updates land the same way: bump appears when a new release is tagged

### Manual Installation (IPK)

1. Download the latest `org.nphil.lumaglass_<version>_all.ipk` from [Releases](https://github.com/nphil/lumaglass/releases)
2. Copy the IPK to the TV via SSH:
   ```bash
   scp org.nphil.lumaglass_*.ipk root@<tv-ip>:/media/developer/
   ```
3. SSH into the TV and install:
   ```bash
   ssh root@<tv-ip>
   ipk-install /media/developer/org.nphil.lumaglass_*.ipk
   ```
4. The app appears in the Homebrew Channel; launch it to apply the mod

## Usage

Launch **LumaGlass** from the Homebrew Channel. The app provides:

- **Apply**: Install the mod (mounts compositor QML and Home app assets, restarts services)
- **Revert**: Remove the mod (unmounts everything, restores original app icons, restarts services)
- **Persist** (on/off): Keep the mod applied across reboots (persists state to `/var/lib/lumaglass/`, and installs the early boot hook described below)
- **FPS** (on/off): Enable compositor FPS debug overlay (for development)
- **Notify**: Configure optional ntfy.sh integration for status/alerts (requires internet + token)
- **Status**: Show current mod state, version, applied mounts, and configuration
- **Log**: View debug logs from recent applies/reverts

## How It Works

The mod uses two bind mounts:

### 1. Compositor Layer (`/usr/lib/qml/WebOSCompositor/views/fullscreen/StarfishFullscreenContainer.qml`)

A custom QML file replaces the stock compositor. It:
- Renders the liquid glass material (three overlapping gradient panes, Rose Pine palette)
- Displays a 1920×1080 abstract wallpaper on top of the dark compositor background
- Provides an optional FPS debug overlay for performance tuning
- Requires restart of `surface-manager-daemon` to take effect (~12 seconds)

### 2. Home App Assets (`/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets`)

A merged copy of the stock Home app assets directory with overlaid modifications:
- **`home.xml`**: Restructured layout, hiding the default hero banner to show the compositor wallpaper
- **`images/{hd,2k,4k}/bg_banner_img.png`**: Pure black (1264×580 / 1920×880 / 3840×1760) blanking the hero region
- **`i18n/en.json`**: Localized strings; greeting uses time-of-day logic ("Morning", "Afternoon", "Evening", "Night")
- Requires termination of the Home app and a relaunch to take effect

The mod state and configuration live in `/var/lib/lumaglass/`, which persists across reboots if persistence is enabled.

### Boot timing

The set resumes a hibernation image rather than cold-booting, and the
compositor inside it starts at 2.63s. It cannot load the modded QML: `/var`
does not show the writable filesystem until `mount-readwrite.service` at
12.96s, so the compositor unit's optional `EnvironmentFile` under `/var` is
not a path that exists yet. One compositor restart per boot is therefore
structural, and ~13s is the floor for applying anything.

With persistence on, the apply runs from a PATH shim in front of `grep` for
`kdump.service` (starts 14.2s) rather than waiting for Homebrew Channel's
`init.d` run-parts at ~33s. The modded home reaches the panel at ~33s, and
stock Home never paints first. Homebrew Channel's hook remains as the
fallback if the early apply fails.

## Firmware Compatibility

The mod is **developed and tested on webOS 10.2.1** (build 5202, Rockhopper chassis). Compatibility with other webOS 10 releases depends on the layout of the compositor QML and Home app structure; a firmware update may break the mod (the TV will still boot and work normally without the mod applied).

To re-apply after a firmware update:
1. Launch LumaGlass in the Homebrew Channel
2. Tap **Apply** (all files are still present in the app's persistent directory)

## Troubleshooting

### Mod not appearing on screen after apply

- Check **Status** in the app: ensure "Applied: yes" and all three mounts are present
- Restart the Home app: swipe up on the home screen or open another app then return
- If compositing still looks wrong, check **Log** for errors; try **Revert** then **Apply** again

### TV appears stuck/frozen after apply

- Revert the mod via the Homebrew Channel → LumaGlass → **Revert** (this unmounts everything)
- Or SSH in and manually: `pkill -f surface-manager-daemon; pkill -f com.webos.app.home; systemctl restart surface-manager-daemon`

### Black/corrupt wallpaper on screen

- The wallpaper must be copied to `/tmp/hx/wall_1080.png` before the compositor starts; check app **Log** for copy errors
- If persisting across reboots, verify `/var/lib/webosbrew/init.d/50-lumaglass` exists and is executable

## Building

### Prerequisites

- Node.js 20+
- ar, tar, sha256sum (standard Linux utilities)
- This repo cloned with git

### Build the IPK

```bash
sh tools/build-ipk.sh
```

This outputs `org.nphil.lumaglass_0.1.0_all.ipk` and validates its structure.

### Generate Manifest

```bash
node tools/gen-manifest.js org.nphil.lumaglass_0.1.0_all.ipk manifest.json
```

Creates a `manifest.json` with package metadata for the Homebrew Channel.

## Development

The mod is packaged as a self-updating homebrew app. Each release (git tag `v*`) triggers:
1. Build of the IPK
2. Generation of `manifest.json` and updated `repo.json`
3. Creation of a GitHub Release with artifacts
4. Commit back to main (with `[skip ci]` to avoid loops)

To release a new version:
1. Update `appinfo.json` version field (e.g., `0.2.0`)
2. Update `CHANGELOG.md`
3. Commit and tag: `git tag v0.2.0 && git push --tags`
4. The release workflow creates the GitHub Release and updates `repo.json` automatically

## Reverting/Uninstalling

The mod is completely non-destructive:

- **Revert**: Launch LumaGlass → **Revert** (removes all mounts, restores original app icons, restarts compositor)
- **Uninstall**: Revert first, then remove the app from Homebrew Channel (or via `ipk-uninstall` on SSH)

After revert, the TV returns to stock appearance and behavior; no system files were modified.

## License

MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

Developed for rooted LG webOS TVs. Tested on webOS 10.2.1. Thanks to the webOS community and Homebrew Channel project.
