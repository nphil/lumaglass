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

# Wait for the compositor. Applying before it is up is pointless: the binds
# would land but the restart that makes them take effect would race the
# compositor's own startup.
waited=0
while [ "$waited" -lt "$MAX_WAIT" ]; do
  if systemctl is-active surface-manager-daemon.service >/dev/null 2>&1; then
    break
  fi
  sleep "$POLL"
  waited=$((waited + POLL))
done

if [ "$waited" -ge "$MAX_WAIT" ]; then
  log "compositor not active after ${MAX_WAIT}s, giving up cleanly"
  exit 0
fi

# Let the first Home launch settle so our restart is not competing with it.
sleep 5

log "compositor up after ${waited}s, applying"
out=$("$CLI" apply 2>&1)
case "$out" in
  *'"ok":true'*) log "apply ok" ;;
  *)             log "apply failed: $(echo "$out" | tr -d '\n' | cut -c1-300)" ;;
esac

exit 0
