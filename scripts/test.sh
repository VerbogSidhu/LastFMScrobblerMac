#!/bin/zsh
set -eu
cd "${0:A:h:h}"
if [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]]; then
    export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
fi
frameworks="$(xcode-select -p)/Library/Developer/Frameworks"
args=(--build-system native --disable-xctest --enable-swift-testing)
if [[ -d "$frameworks/Testing.framework" ]]; then
    args+=(-Xswiftc -F -Xswiftc "$frameworks" -Xlinker -rpath -Xlinker "$frameworks" -Xlinker -rpath -Xlinker "$(xcode-select -p)/Library/Developer/usr/lib")
fi
swift test "${args[@]}" "$@"
