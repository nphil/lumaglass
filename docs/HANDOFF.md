# LumaGlass — engineering handoff

Everything a person or model needs to pick this project up cold: how the mod
works, what was measured on the set, which approaches are dead and why, and
how to measure again. Facts here were observed on one set unless marked
[INFERENCE]. Credentials and the set's address are deliberately absent; they
live with the owner.

## The set

- LG OLED65C4PUA, model code `o22n2`, webOS 10.2.1, firmware 33.22.52, MediaTek
  (`chip=O22A3`), 2 GB RAM, armv7 userspace (`GLIBC_2.28`).
- Rooted with Homebrew Channel. SSH root login via Homebrew Channel's sshd; no
  passwordless sudo, the login is root. `luna-send` from a non-PTY SSH exec
  hangs — allocate a PTY. `journalctl` hangs — read `/var/log/messages`
  (monotonic timestamps in brackets), which rotates within minutes.
- A plain `reboot` returns powered on and is safe to drive over SSH. The luna
  `machineReboot` drops to standby and does not power back on. Wake-on-LAN
  works with `wolwowlOnOff` on (built-in LAN port), so a set in standby or
  fully off can be woken with a magic packet.
- `/sys/power/mode` reads `resume` on a normal boot and `making` on a boot
  that rebuilds the hibernation image.
- Screen capture: `luna://com.webos.service.capture/executeOneShot` with
  `{"path":"/tmp/x.png","method":"DISPLAY","format":"PNG","width":960,"height":540}`,
  then sftp the file. A blank panel returns ~835 bytes at 320x180.

## What the mod is

Two halves, one owner each.

- Compositor: a full shadow copy of the `WebOSCompositor` QML module (318
  files) at `/var/lib/lumaglass/qml`, with `StarfishFullscreenContainer.qml`
  swapped for ours (glass, wallpaper, widgets). `surface-manager-daemon.service`
  has `EnvironmentFile=-/var/systemd/system/env/surface-manager.env`; the mod
  writes `QML2_IMPORT_PATH=/var/lib/lumaglass/qml:/usr/lib/qt5/qml` there.
  `/usr` is a lowerdir-only overlay and can never be written.
- Home: `mount --bind /var/lib/lumaglass/assets` over
  `/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets`
  (decluttered `home.xml`, strings, blank hero banners), then relaunch Home.
  A bind does not survive a reboot.

State lives in `/var/lib/lumaglass/`; the CLI is `tools/lumaglass`, the boot
worker is `tools/autostart.sh`. `status` is the source of truth for what is
live.

## Boot: the proven mechanism

The set does not cold-boot from standby. `/proc/cmdline` carries
`snapshot resume=/dev/mmcblk0p54`, boot status reports
`snapshot-resume-done: true`, and the compositor restored from that image
carries the pid and start time it had when the image was made. A "first
start" of the compositor is therefore a memory restore, and systemd
timestamps read on a resumed boot are values baked into the image, not this
boot's.

On a genuine cold boot (`mode=making`), measured:

| event | monotonic |
| :--- | ---: |
| `mount-dynamic-partition.service` | 1.07–1.32 s |
| `ls-hubd` ExecMainStart | 1.32 s |
| `var.mount` (p58 on /var) active | 1.98 s |
| `surface-manager-daemon` ExecMainStart | 2.63 s |
| `sam.service` | 5.28 s |
| `mount-readwrite.service` active | 10.8–13.1 s |
| `kdump.service` ExecMainStart | 12.1–14.3 s |
| image capture (making boot) | ~15 s |
| Home first paint | ~12–18 s |
| Homebrew Channel `init.d` run-parts | ~33 s |

The compositor's first start can never load the modded QML, and the reason is
the filesystem, not ordering. Until `mount-readwrite.service` relocates it,
`/var` does not show the writable ext4 subtree, so `/var/systemd/system/env`
is not a path that exists yet; the daemon's optional `EnvironmentFile` read at
2.63 s is a silent no-op. Proof:

- The env file's atime, set to 2020 before a cold boot, was untouched after it.
- Marker variables planted in `ls-hubd.env`, `configd.env`, `memchute.env`,
  `tvpowerd.env`, `bootd.env` and `sam.env` were absent from every one of
  those processes' `/proc/<pid>/environ`. LG's own env files are inert that
  early too.
- `/var` is a subtree mount (`mountinfo` root `/var` on p58).
  `/var/systemd/system/env/surface-manager.env` and
  `/mnt/lg/cmn_data/var/systemd/system/env/surface-manager.env` are the same
  inode; `/mnt/lg/cmn_data/systemd` does not exist. A copy staged at p58's
  root was not read either, so the early `/var` is the firmware overlay
  (which holds only `lib`), not any view of p58.

Consequences: one compositor restart per boot is structural, ~13 s is the
floor for anything a root mod can do, and every restart after ~13 s picks the
env file up reliably.

### The early hook

Homebrew Channel's run-parts fires at ~33 s, after Home has painted, which
produced the stock-Home-then-blink-then-mod sequence. The mod now triggers
from `kdump.service`: it starts at 12–14 s, reads
`/var/systemd/system/env/kdump.env`, and its script's first act is a bare
`grep`. `persist on` writes `PATH=/var/lib/lumaglass/earlybin:...` into that
env file and a shim named `grep` into `earlybin` that starts the worker once
per boot and then `exec /bin/grep "$@"`. On a set without `crashkernel` on
the kernel command line the script is a no-op that exits 0, and the unit is
`Restart=no`. The shim uses absolute paths throughout (a bare `grep` inside
it would re-enter itself) and launches the worker with a plain PATH. The late
hook stands down when `/tmp/.lumaglass-worker` names a live pid or the boot
completed.

### Readiness

`systemctl is-active`, the Home process, `NL_HOME_SHOWN` and
`getForegroundAppInfo` all go true ~8 s before anything is composited. The
only honest gate is the panel: `executeOneShot` at 320x180 returns 835 bytes
while blank and >79000 once Home is up. Measured after a restart: content at
+12 s, and asking for Home at +4 s does not delay it. The old sequence slept
14 s before launching Home and 8 s after; both sleeps are gone. The gate is
bounded at 30 s, and on the boot path a timeout is not an error (a boot into
standby never presents).

### Result

Wake from cold, frame-captured every 2 s (`evidence/boot/`): live TV at 12 s
(the image's restored state), black from ~17 s (our restart pre-empts Home's
first paint), modded home fully formed at 33–36 s. Previously ~55–60 s with a
stock-Home phase in between. Whether Home paints before the restart lands is
a race that varies by a second or two per boot.

## Standby: the proven mechanism

After power-off the set enters active standby (RAM alive) within ~3.4 s. A
power-on from there is instant with the mod still on screen. What made it go
cold was `faultmanager`: at power-off it scans
`/tmp/var/log/reports/librdx`, and any report there makes it answer
`responseSuspendRequest` with `ack:false, reason:"rebootToSuspend",
rebootReason:"rebootByFault"`; tvpowerd then reboots ~6 s after entering
standby. Captured on the bus with
`ls-monitor -f com.webos.service.tvpower` written to `/var` (not `/tmp`,
which does not survive the reboot).

Two reports were arming it.

1. The compositor restart makes `com.webos.app.inputcommon` segfault on
   teardown (`QFontDatabase::removeAllApplicationFonts`), landing ~3 s after
   the restart. The sweep meant to remove it never worked: it read names back
   from `ls`, which word-splits on the spaces every name contains and prints
   the 0x02 bytes rdxd uses in place of `/` as `?`; `rm -f` on those names
   was a no-op counted as success. The sweep now uses pathname expansion
   (raw bytes) and runs again once Home is back on the panel.
2. `webos-sddp` (Control4 discovery) crashes on the first wake from active
   standby (`SDDPSetDevice+0x14f`) and stays dead for the rest of the boot.
   Not this mod's. Its script is gated on the set's own `enableSDDP` setting,
   so the **Instant on** toggle (`standby warm`) turns that off and Quick
   Start+ on, remembering the previous value; `standby cold` restores it and
   turns Quick Start+ off.

Measured after both: three power-off / wake cycles of 150 s each with no
reboot, uptime carrying across, the same compositor still running, and Home
from a warm wake painting in 8 s (`evidence/home-after-warm-wake.png`).

Related facts from `tvpowerd`: `com.webos.service.tvpower.instantBootRefreshPeriod`
is 24 (hours) via configd, after which a warm set is refreshed cold once
("Wait for 1 Minute at active standby" then "Go to Cold"). There is a
`warmOwner` / `registerActiveStandbyRequest` protocol
(`{"clientName","timestamp","ack"}` responses) and a learned power-off
history at `/mnt/lg/cmn_data/tvpower/webos_offhistory`; neither needed
touching.

## Tried and dead

- **Baking the mod into the hibernation image.** LG's own remake path is
  `snapshot-boot-manager --remove` then `reboot`; the next boot comes up
  `mode=making` and the kernel writes a fresh image to p54 (250 MB
  partition). Safe — worst case one cold boot, as after a firmware update —
  and exercised several times. It cannot carry the mod: the image is captured
  at ~15 s, before the 13 s floor plus a restart can finish, so the resumed
  compositor is always stock and the asset bind is absent. `snap_list` has no
  Home/sam entry, and `-m` from a live desktop would not fit against ~1.2 GB
  in use.
- **Staging the env file on p58's root** so the early `/var` would see it:
  not read (see above).
- **A unit drop-in or a `/run/systemd/system` unit**: `/etc` and `/usr` are
  read-only overlays; `/run` is writable but volatile and nothing early can
  populate it.
- **Making the restart cheaper**: the 12–16 s from restart to pixels is the
  compositor's cold start plus Home's cold start (`surface-manager.sh` kills
  every client on restart), not padding.

## The other mod on this set

tvweb (`nphil/lg-webos-mqtt`) bind-mounts its own adblock `/etc/hosts`. That
bind stacks on top of Homebrew Channel's, which is how Homebrew's OS-update
block (four LG hosts pointed at loopback) was silently defeated: the TV found
a 1.7 GB firmware update and put its NSU alert up at boot+34 s for 30 s on
every boot. tvweb 0.34.3 carries those hosts whenever
`/var/luna/preferences/webosbrew_block_updates` exists.

## Compositor restart side effects still worth knowing

A bare `systemctl restart surface-manager-daemon` on stock firmware, no mod,
makes stock apps segfault on teardown. `faultmanager`'s policy is in
`/etc/faultmanager/faultconf.json`; `getFaultStatus` lists what it has seen.
The mod removes only the reports its own restart produced.

## Measuring again

- Cold boot on demand: `snapshot-boot-manager --remove; reboot` (expect the
  "making" splash once). Normal reboot: `reboot`.
- Whether the first compositor is stock: its `/proc/<pid>/environ`
  `QML2_IMPORT_PATH`, and `awk '{print int($22/100)}' /proc/<pid>/stat` for
  its start second.
- Panel timeline during boot: a background loop calling `executeOneShot`
  every 2 s from the early shim, recording `writtenBytes`; frames in
  `evidence/boot/` came from that.
- Standby: `ls-monitor -f com.webos.service.tvpower > /var/lib/lumaglass/x.log`
  before `luna://com.webos.service.tvpower/power2/powerOff
  '{"reason":"remoteKey"}'`; wake with a WoL packet; compare `/proc/uptime`
  before and after. SSH survives active standby.

## Research

`research/home-launcher-replacements.md` surveys other rooted-webOS home
replacements and the input-hook tooling around them; it informed the choice
to mod the compositor and Home in place rather than launch over them.
