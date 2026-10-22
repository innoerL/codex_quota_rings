#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h:h}"

quota_stage=$(mktemp -d "${TMPDIR:-/tmp}/quota-rings-staging.XXXXXX")
trap 'rm -rf "$quota_stage"' EXIT
quota_stage_app="$quota_stage/Quota Rings.app"
quota_stage_zip="$quota_stage/Quota-Rings.app.zip"
quota_arm_binary="$quota_stage/QuotaRings-arm64"
quota_intel_binary="$quota_stage/QuotaRings-x86_64"
mkdir -p "$quota_stage/module-cache-arm64" "$quota_stage/module-cache-x86_64" "$quota_stage_app/Contents/MacOS"

swiftc -swift-version 5 -O -target arm64-apple-macosx12.0 \
  -module-cache-path "$quota_stage/module-cache-arm64" Sources/*.swift \
  -o "$quota_arm_binary" -framework AppKit
swiftc -swift-version 5 -O -target x86_64-apple-macosx12.0 \
  -module-cache-path "$quota_stage/module-cache-x86_64" Sources/*.swift \
  -o "$quota_intel_binary" -framework AppKit
/usr/bin/lipo -create "$quota_arm_binary" "$quota_intel_binary" -output "$quota_stage_app/Contents/MacOS/QuotaRings"
quota_archs=$(/usr/bin/lipo -archs "$quota_stage_app/Contents/MacOS/QuotaRings")
[[ " $quota_archs " == *" arm64 "* && " $quota_archs " == *" x86_64 "* ]] || {
  print -u2 "Universal 2 验证失败：$quota_archs"; exit 1
}

cp Scripts/Info.plist "$quota_stage_app/Contents/Info.plist"
/usr/bin/codesign --force --sign - "$quota_stage_app"
/usr/bin/codesign --verify --deep --strict "$quota_stage_app"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$quota_stage_app" "$quota_stage_zip"
/usr/bin/unzip -tq "$quota_stage_zip" >/dev/null

# Prepare every replacement before touching the previous release.
mkdir -p build outputs/QuotaRings
quota_build_new='build/.Quota Rings.app.new'
quota_release_new='outputs/QuotaRings/.Quota Rings.app.new'
quota_zip_new='outputs/QuotaRings/.Quota-Rings.app.zip.new'
rm -rf "$quota_build_new" "$quota_release_new" "$quota_zip_new"
/usr/bin/ditto "$quota_stage_app" "$quota_build_new"
/usr/bin/ditto "$quota_stage_app" "$quota_release_new"
cp "$quota_stage_zip" "$quota_zip_new"
/usr/bin/codesign --verify --deep --strict "$quota_build_new"
/usr/bin/codesign --verify --deep --strict "$quota_release_new"
/usr/bin/unzip -tq "$quota_zip_new" >/dev/null

rm -rf 'build/Quota Rings.app' 'outputs/QuotaRings/Quota Rings.app'
rm -f 'outputs/QuotaRings/Quota-Rings.app.zip'
mv "$quota_build_new" 'build/Quota Rings.app'
mv "$quota_release_new" 'outputs/QuotaRings/Quota Rings.app'
mv "$quota_zip_new" 'outputs/QuotaRings/Quota-Rings.app.zip'

print "构建完成：$PWD/outputs/QuotaRings/Quota Rings.app"
print "安装包：$PWD/outputs/QuotaRings/Quota-Rings.app.zip"
