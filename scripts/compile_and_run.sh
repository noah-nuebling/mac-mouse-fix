#!/usr/bin/env bash

# Mac Mouse Fix Compile and Run Script
# Inspired by LiquidConvert with structured logging and safety checks.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Mac Mouse Fix"
ARCH=$(uname -m)
APP_PROCESS_PATTERN="${APP_NAME}.app/Contents/MacOS/${APP_NAME}"

# Structured logging
log()  { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

run_step() {
  local label="$1"; shift
  log "==> ${label}"
  if ! "$@"; then
    fail "${label} failed"
  fi
}

kill_all_instances() {
  log "==> Terminating all existing ${APP_NAME} and Helper instances..."
  
  # Phase 0: Bootout launchd helper service if registered
  launchctl bootout gui/$(id -u)/com.nuebling.mac-mouse-fix.helper 2>/dev/null || true
  
  # Phase 1: Forceful kill right away for app and helper
  killall -9 "${APP_NAME} Helper" 2>/dev/null || true
  killall -9 "${APP_NAME}" 2>/dev/null || true
  
  # Phase 2: Thorough check and pkill with pattern
  pkill -9 -f "${APP_NAME} Helper" 2>/dev/null || true
  pkill -9 -f "${APP_PROCESS_PATTERN}" 2>/dev/null || true
  
  # Phase 3: Wait a moment for OS to clean up
  sleep 1
  
  if pgrep -f "${APP_PROCESS_PATTERN}" >/dev/null 2>&1; then
    log "WARNING: Some instances might still be lingering. Trying one last time..."
    pgrep -f "${APP_PROCESS_PATTERN}" | xargs kill -9 2>/dev/null || true
    sleep 1
  fi
}

# --- Execution ---

# 1) Build only the current architecture app bundle and skip DMG packaging for dev loops
run_step "Building ${APP_NAME} (debug)" env BUILD_ARCHS="${ARCH}" SKIP_DMG=1 CODE_SIGN_IDENTITY="-" "${ROOT_DIR}/scripts/build.sh" debug

APP_BUNDLE="${ROOT_DIR}/${APP_NAME}_${ARCH}.app"
if [ ! -d "${APP_BUNDLE}" ]; then
  APP_BUNDLE="${ROOT_DIR}/${APP_NAME}.app"
fi
APP_EXECUTABLE="${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
if [ ! -x "${APP_EXECUTABLE}" ]; then
  fail "Built app executable not found at ${APP_EXECUTABLE}"
fi

# 2) Cleanup
kill_all_instances

# 3) Deploy & Launch
log "==> Deploying to /Applications for proper SMAppService registration..."
rm -rf "/Applications/${APP_NAME}.app"
cp -R "${APP_BUNDLE}" "/Applications/${APP_NAME}.app"
xattr -d com.apple.quarantine "/Applications/${APP_NAME}.app" 2>/dev/null || true
xattr -cr "/Applications/${APP_NAME}.app" || true

if [[ "${MMF_RESIGN_INSTALLED_APP:-0}" == "1" ]]; then
  log "==> Re-signing installed app as requested"
  codesign --force --deep --sign "${CODE_SIGN_IDENTITY:--}" "/Applications/${APP_NAME}.app"
fi

if [[ "${MMF_RESET_ACCESSIBILITY:-0}" == "1" ]]; then
  log "==> Resetting Accessibility permissions as requested..."
  tccutil reset Accessibility com.nuebling.mac-mouse-fix 2>/dev/null || true
  tccutil reset Accessibility com.nuebling.mac-mouse-fix.helper 2>/dev/null || true
fi

log "==> Launching app from /Applications"
INSTALLED_APP="/Applications/${APP_NAME}.app"
INSTALLED_EXECUTABLE="${INSTALLED_APP}/Contents/MacOS/${APP_NAME}"
open -na "${INSTALLED_APP}"
sleep 1
osascript -e "tell application \"${INSTALLED_APP}\" to activate" >/dev/null 2>&1 || true

# 4) Verify
log "==> Verifying application state"
for _ in {1..10}; do
  APP_PID=$(pgrep -n -f "${INSTALLED_EXECUTABLE}" || true)
  if [ -n "${APP_PID}" ] && ps -p "${APP_PID}" > /dev/null; then
    log "Launched ${APP_NAME} (PID: ${APP_PID})"
    log "OK: ${APP_NAME} is running"
    log "==> All development loop steps completed successfully."
    exit 0
  fi
  sleep 0.5
done

fail "App exited immediately or failed to start."
