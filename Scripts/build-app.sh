#!/bin/bash
set -euo pipefail

cd -- "$(dirname -- "$0")/.."
version=$(<VERSION)
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'Invalid version in VERSION\n' >&2
  exit 1
fi

output=${1:-"$PWD/dist"}
scratch=${HUBGLIDE_BUILD_DIR:-"$PWD/.build"}
mkdir -p -- "$output"
output=$(cd -- "$output" && pwd)
app="$output/HubGlide.app"
if [[ -e "$app" ]]; then
  printf 'Choose a fresh output directory. This bundle already exists: %s\n' "$app" >&2
  exit 1
fi

swift build -c release --product HubGlide --scratch-path "$scratch"
product=$(swift build -c release --scratch-path "$scratch" --show-bin-path)
staging=$(mktemp -d "$output/.hubglide.XXXXXXXX")
trap 'rm -rf -- "$staging"' EXIT
bundle="$staging/HubGlide.app"
mkdir -p "$bundle/Contents/"{MacOS,Resources} "$staging/HubGlide.iconset"
install -m 755 "$product/HubGlide" "$bundle/Contents/MacOS/HubGlide"
cp Resources/Info.plist "$bundle/Contents/Info.plist"
for key in CFBundleShortVersionString CFBundleVersion; do
  /usr/libexec/PlistBuddy -c "Set :$key $version" "$bundle/Contents/Info.plist"
done
swift Scripts/icon.swift "$staging/HubGlide.iconset"
iconutil -c icns "$staging/HubGlide.iconset" -o "$bundle/Contents/Resources/HubGlide.icns"
cp LICENSE "$bundle/Contents/Resources/LICENSE"
identity=${HUBGLIDE_SIGN_IDENTITY:--}
timestamp=--timestamp
if [[ "$identity" == "-" ]]; then timestamp=--timestamp=none; fi
codesign --force --sign "$identity" --options runtime "$timestamp" "$bundle"
codesign --verify --strict "$bundle"
mv -- "$bundle" "$app"
printf 'Built %s\n' "$app"
