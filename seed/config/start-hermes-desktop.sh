#!/usr/bin/env bash
# Launch the Hermes Agent desktop app on this machine.
#
# Every line below exists because of something that actually failed when this
# image was first built:
#
#   1. HERMES_HOME must be set explicitly — without it Hermes silently creates a
#      SECOND, empty home under the login user's directory (cost us a 2 GB
#      duplicate browser download).
#   2. Electron's sandbox cannot initialise inside a container: the app dies with
#      "zygote_host_impl_linux.cc: CHECK failed: Invalid argument".
#      ELECTRON_DISABLE_SANDBOX=1 is the supported environment switch; the same
#      thing is also written into the agent's own config as
#      desktop.electron_flags ["--no-sandbox"] at install time. Either alone is
#      enough; both together are harmless. The app already runs inside an
#      isolated container, which is the real boundary.
#   3. HERMES_DESKTOP_HERMES tells the app which CLI is its backend. Without it
#      the app cannot resolve the install and stalls forever on "Waiting for
#      first-run setup choice" — a screen that looks like a broken install but is
#      really just an unanswered question.
#   4. HERMES_DESKTOP_HERMES_ROOT points at the source checkout. Without it the
#      app falls back to a "managed install", reports install_method=unknown and
#      its in-app Update fails with "Not a git repository".
#   5. DISPLAY is pinned to the desktop session's display.
#
# --skip-build: launch the already-built app. Rebuild deliberately after an
# update with: hermes desktop --build-only
#
# --quiet: no dialog when the agent is still being installed. Used by the
# autostart entry, so a fresh machine does not greet you with a popup before the
# background install has finished.
#
# Paths on this image:
#   HERMES_HOME  /config/.hermes        (on the mounted volume)
#   CLI          /config/.local/bin/hermes
#   checkout     /config/hermes-agent

set -u

QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

export HERMES_HOME=/config/.hermes
export PATH="/config/.local/bin:$PATH"
export ELECTRON_DISABLE_SANDBOX=1
export HERMES_DESKTOP_HERMES=/config/.local/bin/hermes
export HERMES_DESKTOP_HERMES_ROOT=/config/hermes-agent
export DISPLAY="${DISPLAY:-:1}"

# Already open? Do nothing, so autostart cannot stack duplicates.
if pgrep -f "linux-unpacked/Hermes" >/dev/null 2>&1; then
  exit 0
fi

# First boot: the agent install runs in the background (custom-cont-init.d/
# 90-firstboot) and takes several minutes. Clicking the icon before it finishes
# must say so rather than die with "command not found"; the install continues
# either way and the next click works.
if [ ! -x /config/.local/bin/hermes ]; then
  if [ "$QUIET" = "0" ]; then
    MSG="Hermes Agent is still being installed — this takes a few minutes on first boot.
Follow it with:  tail -f /config/logs/firstboot.log"
    echo "$MSG"
    if command -v zenity >/dev/null 2>&1; then
      zenity --info --width=460 --title="Hermes Agent" --text="$MSG" 2>/dev/null || true
    fi
  fi
  exit 0
fi

cd /config || exit 1
exec /config/.local/bin/hermes desktop --skip-build
