#!/bin/zsh
# Compiles the real RemapSwizzler.m against the stubs in Stubs/ and runs RemapSwizzlerTests.m.
# Usage: Helper/Core/Remap/Tests/run_tests.sh
# RemapSwizzler.m is copied next to the stubs first, so its #import "Remap.h" etc. find the stubs instead of the real headers.
set -e
HERE=${0:A:h}
ROOT=${HERE:h:h:h:h}
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
cp "$ROOT/Helper/Core/Remap/RemapSwizzler.m" "$ROOT/Helper/Core/Remap/RemapSwizzler.h" "$HERE"/Stubs/* "$HERE/RemapSwizzlerTests.m" "$OUT/"
clang -fobjc-arc -fmodules -w \
    -include CoreGraphics/CoreGraphics.h -include "$ROOT/Shared/Constants.h" \
    -I "$OUT" -I "$ROOT/Shared" \
    "$OUT/RemapSwizzler.m" "$OUT/Stubs.m" "$OUT/RemapSwizzlerTests.m" \
    -framework Foundation -framework CoreGraphics -o "$OUT/RemapSwizzlerTests"
"$OUT/RemapSwizzlerTests"
