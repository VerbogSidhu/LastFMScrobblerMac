#!/bin/zsh
set -eu
cd "${0:A:h:h}"
# The macOS 27 CLT SDK lacks the SwiftUI macro plug-in on this development Mac.
if [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]]; then
    export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
fi
swift build --build-system native
stage="$(mktemp -d "${TMPDIR:-/tmp}/lastfm-build.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
bundle="$stage/LastFM.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp -X .build/debug/LastFM "$bundle/Contents/MacOS/LastFM"
cp -X Info.plist "$bundle/Contents/Info.plist"
/usr/bin/xattr -cr "$bundle"
/usr/bin/codesign --force --sign - "$bundle"
/usr/bin/codesign --verify --deep --strict "$bundle"
/usr/bin/ditto --noextattr --norsrc "$bundle" .build/LastFM.app
/usr/bin/ditto -c -k --norsrc --noextattr --keepParent "$bundle" .build/LastFM.zip
print "Built $PWD/.build/LastFM.app and .build/LastFM.zip"
