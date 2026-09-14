#!/bin/sh
# LumaGlass boot hook.
#
# Symlinked to /var/lib/webosbrew/init.d/50-lumaglass by `lumaglass persist on`
# and run by Homebrew Channel's startup.sh via run-parts during boot.
#
# Two hard rules, because this runs on the boot path:
#
#   1. It must ALWAYS exit 0. A non-zero exit from an init.d hook can trip
#      Homebrew Channel's failsafe mode, which disables every root
#      customization on the next boot and shows the user a crash toast. A
#      cosmetic mod is never worth that, so every failure here is logged and
#      swallowed.
#   2. It must never block boot indefinitely. Every wait is bounded and the
#      whole run is capped.
#
# The hook is also a no-op unless the user explicitly asked for persistence,
# so removing the symlink is not the only off switch.

STATE=/var/lib/lumaglass
LOG="$STATE/log"
MAX_WAIT=90        # seconds to wait for the compositor to come up
POLL=2

# Resolve the real app dir even though we are invoked through a symlink
# in /var/lib/webosbrew/init.d.
self="$0"
if [ -L "$self" ]; then
  target=$(readlink "$self" 2>/dev/null)
  case "$target" in
    /*) self="$target" ;;
    *)  self="$(dirname "$self")/$target" ;;
  esac
fi
APPDIR=$(cd "$(dirname "$self")/.." 2>/dev/null && pwd)
CLI="$APPDIR/tools/lumaglass"

log() {
  mkdir -p "$STATE" 2>/dev/null
  echo "$(date '+%Y-%m-%d %H:%M:%S') boot: $1" >> "$LOG" 2>/dev/null
}

# Never let anything below abort the boot path.
trap 'log "hook aborted unexpectedly"; exit 0' HUP INT TERM

if [ ! -x "$CLI" ]; then
  log "cli not found at $CLI (app uninstalled?), nothing to do"
  exit 0
fi

# Honour the opt-in flag as well as the symlink's presence.
if ! grep -q '"persist"[[:space:]]*:[[:space:]]*true' "$STATE/config.json" 2>/dev/null; then
  log "persist disabled in config, skipping"
  exit 0
fi

# --worker: the detached half.
#
# Order matters here and is measured, not guessed: the compositor starts about
# two seconds after this worker. boot-bind mounts the previous boot's verified
# set in well under a second, so the compositor reads the modded QML on its
# first start. The full apply that follows then finds the set unchanged and
# the compositor already showing it, and makes no restart - which is the
# difference between a clean boot and a fifteen-second black screen.
if [ "$1" = "--worker" ]; then
  bb=$("$CLI" boot-bind 2>&1)
  log "boot-bind: $(echo "$bb" | tr -d '\n' | cut -c1-200)"
  out=$("$CLI" apply 2>&1)
  case "$out" in
    *'"ok":true'*) log "apply ok"; "$CLI" boot-ok >/dev/null 2>&1 ;;
    *)             log "apply failed: $(echo "$out" | tr -d '\n' | cut -c1-300)" ;;
  esac
  exit 0
fi

# Everything below runs DETACHED, and that is the whole point.
#
# Homebrew Channel's startup.sh arms a failsafe flag, runs these hooks with
# run-parts, then clears the flag ~10s later. A hook that blocks holds that
# window open for as long as it runs: if the set powers off before the flag is
# cleared, the next boot comes up in failsafe mode with every root
# customization disabled. Applying inline took ~45s, so an overnight power-off
# landed inside the window and did exactly that.
#
# So: return to run-parts immediately and do the work in a detached child.
# startup.sh closes the lock fd for children (`run-parts ... 200>&-`), so the
# child cannot hold Homebrew Channel's startup lock either.
setsid "$APPDIR/tools/autostart.sh" --worker </dev/null >/dev/null 2>&1 &
exit 0
