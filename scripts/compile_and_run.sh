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
  
  # Phase 0: Bootout launchd helper service if registered (including stuck EX_CONFIG legacy jobs)
  launchctl bootout gui/$(id -u)/com.nuebling.mac-mouse-fix.helper 2>/dev/null || true
  launchctl remove com.nuebling.mac-mouse-fix.helper 2>/dev/null || true
  launchctl remove mouse.fix.helper 2>/dev/null || true
  
  # Phase 1: Graceful then forceful kill for app and helper
  killall "${APP_NAME} Helper" 2>/dev/null || true
  killall "${APP_NAME}" 2>/dev/null || true
  sleep 0.3
  killall -9 "${APP_NAME} Helper" 2>/dev/null || true
  killall -9 "${APP_NAME}" 2>/dev/null || true
  
  # Phase 2: Thorough check and pkill with pattern
  pkill -9 -f "${APP_NAME} Helper" 2>/dev/null || true
  pkill -9 -f "${APP_PROCESS_PATTERN}" 2>/dev/null || true
  
  # Phase 3: Wait a moment for OS to clean up
  sleep 0.5
}

# --- Execution ---

# 1) Build only the current architecture app bundle with valid Apple Development signing
run_step "Building ${APP_NAME} (debug)" env BUILD_ARCHS="${ARCH}" SKIP_DMG=1 CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-Apple Development}" "${ROOT_DIR}/scripts/build.sh" debug

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

# 3) Deploy & Launch (use in-place rsync --delete without rm -rf first to avoid launchd EX_CONFIG=78 and stale subcomponents)
log "==> Deploying to /Applications for proper SMAppService registration..."
rsync -a --delete "${APP_BUNDLE}/" "/Applications/${APP_NAME}.app/"
xattr -cr "/Applications/${APP_NAME}.app" || true

if [[ "${MMF_RESIGN_INSTALLED_APP:-0}" == "1" ]]; then
  log "==> Re-signing installed app as requested"
  codesign --force --deep --sign "${CODE_SIGN_IDENTITY:-Apple Development}" "/Applications/${APP_NAME}.app"
fi

run_step "Verifying main app code signature" codesign --verify --deep --strict --verbose=2 "/Applications/${APP_NAME}.app"
run_step "Verifying helper code signature" codesign --verify --strict --verbose=2 "/Applications/${APP_NAME}.app/Contents/Library/LoginItems/${APP_NAME} Helper.app"

if [[ "${MMF_RESET_ACCESSIBILITY:-0}" == "1" ]]; then
  log "==> Resetting Accessibility permissions as requested..."
  tccutil reset Accessibility com.nuebling.mac-mouse-fix 2>/dev/null || true
  tccutil reset Accessibility com.nuebling.mac-mouse-fix.helper 2>/dev/null || true
fi

log "==> Launching Helper and App from /Applications"
INSTALLED_APP="/Applications/${APP_NAME}.app"
INSTALLED_EXECUTABLE="${INSTALLED_APP}/Contents/MacOS/${APP_NAME}"
open -a "${INSTALLED_APP}/Contents/Library/LoginItems/${APP_NAME} Helper.app" || true
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
