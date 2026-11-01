#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
bin=$(mktemp /tmp/mmf-logitech-test.XXXXXX)
trap 'rm -f "$bin"' EXIT
xcrun clang -std=c11 -Wall -Wextra -Werror -fsanitize=address,undefined Tests/Logitech/protocol-state.c -o "$bin"
"$bin"
xcrun clang -fobjc-arc -fblocks -Wno-unused-variable -I Tests/Logitech/stubs \
    -fsanitize=address,undefined Tests/Logitech/lifecycle.m \
    -framework Foundation -framework AppKit -framework IOKit -framework CoreGraphics -o "$bin"
"$bin"

python3 Tests/Logitech/popup-cell.py
