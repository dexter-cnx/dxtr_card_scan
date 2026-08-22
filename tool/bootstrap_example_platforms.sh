#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
example_dir="$root_dir/example"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

flutter create "$tmp_dir/host" \
  --platforms=android,ios \
  --project-name=dxtr_card_scan_example \
  --org=dev.cnxdev

rm -rf "$example_dir/android" "$example_dir/ios"
cp -R "$tmp_dir/host/android" "$example_dir/android"
cp -R "$tmp_dir/host/ios" "$example_dir/ios"

python3 - "$example_dir/ios/Runner/Info.plist" <<'PY'
import plistlib
import sys

path = sys.argv[1]
with open(path, 'rb') as f:
    data = plistlib.load(f)
data['NSCameraUsageDescription'] = 'Capture cards for scanning.'
data['NSPhotoLibraryUsageDescription'] = 'Choose card images for manual cropping.'
with open(path, 'wb') as f:
    plistlib.dump(data, f, sort_keys=False)
PY

python3 - "$example_dir/ios/Runner.xcodeproj/project.pbxproj" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text()
team_id = 'ZTM9BCJPY9'

if 'DEVELOPMENT_TEAM =' in text:
    text = re.sub(
        r'DEVELOPMENT_TEAM = [^;]*;',
        f'DEVELOPMENT_TEAM = {team_id};',
        text,
    )
else:
    text = text.replace(
        'PRODUCT_BUNDLE_IDENTIFIER = dev.cnxdev.dxtrCardScanExample;',
        f'DEVELOPMENT_TEAM = {team_id};\n\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = dev.cnxdev.dxtrCardScanExample;',
    )

path.write_text(text)
PY

echo "Generated example Android/iOS host scaffolding with iOS development team ZTM9BCJPY9."
