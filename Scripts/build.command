#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h:h}"
quota_cache="${TMPDIR:-/tmp}/codex-quota-rings/module-cache"
quota_app='build/Quota Rings.app'
mkdir -p "$quota_cache" "$quota_app/Contents/MacOS"
swiftc -swift-version 5 -O -target "$(uname -m)-apple-macosx12.0" -module-cache-path "$quota_cache" Sources/*.swift -o "$quota_app/Contents/MacOS/QuotaRings" -framework AppKit
cp Scripts/Info.plist "$quota_app/Contents/Info.plist"
/usr/bin/codesign --force --sign - "$quota_app"
print "构建完成：$PWD/$quota_app"
