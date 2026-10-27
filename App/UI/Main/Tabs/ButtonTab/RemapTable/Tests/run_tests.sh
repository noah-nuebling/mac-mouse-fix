#!/bin/zsh
# Compiles the real ShortcutLibrary.m and runs ShortcutLibraryTests.m.
# Usage: App/UI/Main/Tabs/ButtonTab/RemapTable/Tests/run_tests.sh
set -e
HERE=${0:A:h}
ROOT=${HERE:h:h:h:h:h:h:h}
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
clang -fobjc-arc -fmodules -w -DNDEBUG \
    -I "$ROOT/App/UI/Main/Tabs/ButtonTab/RemapTable" -I "$ROOT/Shared" \
    "$ROOT/App/UI/Main/Tabs/ButtonTab/RemapTable/ShortcutLibrary.m" "$HERE/ShortcutLibraryTests.m" \
    -framework Foundation -framework Carbon -o "$OUT/ShortcutLibraryTests"
"$OUT/ShortcutLibraryTests"
