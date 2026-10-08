#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h:h}"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
git init -q "$fixture"
mkdir -p "$fixture/Sources" "$fixture/build/Quota Rings.app"
touch "$fixture/Sources/Sample.swift"
git -C "$fixture" add Sources
zsh Scripts/check-public-tree.sh "$fixture"
touch "$fixture/build/Quota Rings.app/private-data"
git -C "$fixture" add -f build
if zsh Scripts/check-public-tree.sh "$fixture" >/dev/null 2>&1; then
    print -u2 'FAIL: tracked app must be rejected'; exit 1
fi
print 'PASS: public-tree check accepts source and rejects generated app data'
