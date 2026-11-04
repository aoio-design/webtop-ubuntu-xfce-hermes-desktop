#!/bin/bash
# Run one scheduled script under the container's plain cron and deliver its
# output to a messaging channel.
#
# Why this exists: the mechanical jobs (studio keep-alive, backups, update
# checks) run from the container's own cron rather than from the agent's cron,
# so that they keep running even if the agent's CLI is broken, mid-update, or
# the desktop app is closed. The agent delivers a no-agent job's stdout to the
# chat itself; under plain cron that output would just disappear, so this
# wrapper sends it instead.
#
# Every script it is used with prints ONLY when it has something to say, so in
# normal operation this is silent and sends nothing. Exit code is always 0 (a
# failure is logged, never alerted on its own — the script's own output is the
# alert).
#
# NO CREDENTIALS ARE IN THIS FILE, and none are baked into the image. The token
# and chat id are read at run time, from the buyer's own env file; if they are
# not there, the delivery step is skipped and the log line is still written.
# File format expected (two lines, optionally among others):
#   TELEGRAM_BOT_TOKEN=...
#   TELEGRAM_HOME_CHANNEL=...
#
# Usage:  cron-notify.sh "<label>" /path/to/script.sh [args...]

set -u
LABEL="${1:-job}"; shift || true
ENV_FILE="${AOIO_NOTIFY_ENV:-${HERMES_HOME:-/config/.hermes}/.env}"

OUT=$("$@" 2>&1); rc=$?
# Log every send, with its timestamp: the first question after an alert-shaped
# message lands on a phone is "who sent that and when", and stdout captured
# here is otherwise invisible once it has been delivered.
SENT_LOG=/config/cron-notify.log
send() {
  printf '%s | %s | %s\n' "$(date -Is)" "$LABEL" "$(printf '%s' "$1" | tr '\n' ' ' | cut -c1-300)" >> "$SENT_LOG"
  TOKEN=$(grep -m1 '^TELEGRAM_BOT_TOKEN=' "$ENV_FILE" 2>/dev/null | cut -d= -f2-)
  CHAT=$(grep -m1 '^TELEGRAM_HOME_CHANNEL=' "$ENV_FILE" 2>/dev/null | cut -d= -f2-)
  if [ -n "${TOKEN:-}" ] && [ -n "${CHAT:-}" ]; then
    curl -sS -m 25 -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
      -d "chat_id=${CHAT}" --data-urlencode "text=[${LABEL}] $1" -o /dev/null || true
  fi
}
# Hermes's cron invoked these scripts through bash, so the exec bit was never
# required. Plain cron calls them directly, and a 126 (permission denied) is
# silent apart from this log — so fall back to bash when the target is not
# executable. Found by testing, not by reading.
if [ "$rc" -eq 126 ] && [ -f "${1:-}" ]; then
  OUT=$(bash "$@" 2>&1); rc=$?
fi

if [ -n "${OUT//[[:space:]]/}" ]; then
  send "$OUT"
fi

if [ "$rc" -ne 0 ]; then
  echo "$(date -Is) [$LABEL] exited $rc" >> /config/hermes-cron.log
fi
exit 0
