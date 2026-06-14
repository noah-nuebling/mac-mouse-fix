#!/usr/bin/env bash

# Mac Mouse Fix Run Script
# Usage: ./scripts/run.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Mac Mouse Fix"
ARCH=$(uname -m)
APP_BUNDLE="${ROOT_DIR}/${APP_NAME}_${ARCH}.app"

if [[ ! -d "$APP_BUNDLE" ]]; then
    APP_BUNDLE="${ROOT_DIR}/${APP_NAME}.app"
fi

if [[ ! -d "$APP_BUNDLE" ]]; then
    echo "ERROR: App bundle not found. Please run ./scripts/build.sh first."
    exit 1
fi

echo "==> Launching ${APP_NAME}..."
open "$APP_BUNDLE"
