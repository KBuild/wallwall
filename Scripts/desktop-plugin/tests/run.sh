#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
stage=$(mktemp -d "${TMPDIR:-/tmp}/wallwall-tests.XXXXXX")
trap 'rm -rf "$stage"' EXIT HUP INT TERM
swift_bin=$(xcrun --find swiftc)
swift_lib=$(dirname "$swift_bin")/../lib/swift/macosx
(cd "$stage"; xcrun swiftc -O -whole-module-optimization -parse-as-library -emit-object -module-name WallwallDesktop \
    -emit-objc-header-path "$stage/WallwallDesktop-Swift.h" \
    -module-cache-path "$stage/cache" "$here/../WallwallSettings.swift" "$here/../WallwallDisplaySelection.swift" "$here/../WallwallDragState.swift" "$here/../WallwallRenderPolicy.swift" \
    "$here/../WallwallPointer.swift" "$here/../WallwallFallback.swift" "$here/../WallwallDesktopHost.swift" -o "$stage/settings.o")
xcrun clang -fobjc-arc -framework AppKit -framework AVFoundation -I "$stage" \
    "$here/SettingsTests.m" "$stage/settings.o" -L "$swift_lib" \
    -Wl,-rpath,/usr/lib/swift -o "$stage/settings-tests"
"$stage/settings-tests"
xcrun clang -fobjc-arc -framework AppKit -framework AVFoundation -I "$stage" \
    "$here/PolicyTests.m" "$stage/settings.o" -L "$swift_lib" \
    -Wl,-rpath,/usr/lib/swift -o "$stage/policy-tests"
"$stage/policy-tests"
xcrun clang -fobjc-arc -framework AppKit -framework AVFoundation -I "$stage" \
    "$here/BridgeTests.m" "$here/../WallwallBridge.m" "$stage/settings.o" -L "$swift_lib" \
    -Wl,-rpath,/usr/lib/swift -o "$stage/bridge-tests"
"$stage/bridge-tests"
(cd "$stage"; xcrun swiftc -parse-as-library -module-cache-path "$stage/cache" \
    "$here/../"*.swift "$here/HostStateTests.swift" -o "$stage/host-tests")
"$stage/host-tests"
