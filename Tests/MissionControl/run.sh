#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
output=$(mktemp -d /tmp/mmf-mission-control.XXXXXX)
trap 'rm -rf "$output"' EXIT
xcrun clang -Wall -Wextra -Werror -Wno-unused-parameter -fobjc-arc -fmodules \
  -fmodules-cache-path="$output/modules" -framework Foundation -framework CoreGraphics \
  -I Helper/Core/Actions Helper/Core/Actions/MissionControlPreviews.m \
  Tests/MissionControl/tests.m -o "$output/tests"
"$output/tests"
python3 - <<'PY'
import json
from pathlib import Path
root=Path('.')
strings=json.loads((root/'Localization/Localizable.xcstrings').read_text())['strings']
for key in ('effect.mission-control-previews', 'effect.mission-control-previews.hint'):
    assert strings[key]['localizations']['en']['stringUnit']['value']
translator=(root/'App/UI/Main/Tabs/ButtonTab/RemapTable/RemapTableTranslator.m').read_text()
assert 'kMFActionDictKeyGenericVariant: @(kMFSHMissionControl)' in translator
assert 'kMFActionDictKeyType: kMFActionDictTypeMissionControlPreviews' in translator
print('PASS: new UI strings and separate ordinary Mission Control mapping')
PY
