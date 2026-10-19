#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
clang -Wall -Wextra -Werror \
  Tests/InstantSpaces/SwitchingTests.c \
  Helper/Core/Drag/ThreeFingerSwipe/InstantSpaceSwitcher/event_serialize.c \
  -framework ApplicationServices -framework CoreFoundation \
  -o "$test_dir/switching-tests"
ISS_FORCE_EVENT_AUGMENTATION=0 "$test_dir/switching-tests"
ISS_FORCE_EVENT_AUGMENTATION=1 "$test_dir/switching-tests"

# Compile the actual output plugin with stand-ins for its external dependencies.
# The full Xcode build separately checks integration with MMF's real headers.
cp Helper/Core/Drag/ThreeFingerSwipe/ModifiedDragOutputThreeFingerSwipe.m "$test_dir/"
cp Tests/InstantSpaces/Stubs/* "$test_dir/"
mkdir -p "$test_dir/InstantSpaceSwitcher/include"
cp Helper/Core/Drag/ThreeFingerSwipe/InstantSpaceSwitcher/include/ISS.h "$test_dir/InstantSpaceSwitcher/include/"
clang -fobjc-arc -fmodules -Wall -Wextra -Werror -I "$test_dir" \
  "$test_dir/ModifiedDragOutputThreeFingerSwipe.m" \
  Tests/InstantSpaces/DragRoutingTests.m -framework Cocoa -o "$test_dir/drag-tests"
"$test_dir/drag-tests"
