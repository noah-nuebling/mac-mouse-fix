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
