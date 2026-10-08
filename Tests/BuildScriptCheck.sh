#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h:h}"

script=Scripts/build.command
rg -q -- '-target arm64-apple-macosx12\.0' "$script"
rg -q -- '-target x86_64-apple-macosx12\.0' "$script"
rg -q 'module-cache-arm64' "$script"
rg -q 'module-cache-x86_64' "$script"
rg -q 'lipo.*-create' "$script"
rg -q 'lipo.*-archs' "$script"
rg -q 'codesign.*--verify.*--deep.*--strict' "$script"
rg -q 'unzip.*-t' "$script"
rg -q 'stage|staging' "$script"

fixture=$(mktemp -d "${TMPDIR:-/tmp}/quota-build-check.XXXXXX")
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/repo/Scripts" "$fixture/repo/Sources" "$fixture/repo/outputs/QuotaRings" "$fixture/bin"
cp Scripts/build.command Scripts/Info.plist "$fixture/repo/Scripts/"
touch "$fixture/repo/Sources/App.swift"
print -r -- 'previous release' > "$fixture/repo/outputs/QuotaRings/sentinel.txt"
cat > "$fixture/bin/swiftc" <<'EOF'
#!/bin/zsh
exit 73
EOF
chmod +x "$fixture/bin/swiftc" "$fixture/repo/Scripts/build.command"
if PATH="$fixture/bin:/usr/bin:/bin" zsh "$fixture/repo/Scripts/build.command" >/dev/null 2>&1; then
    print -u2 'FAIL: architecture compile failure must fail the build'; exit 1
fi
[[ "$(cat "$fixture/repo/outputs/QuotaRings/sentinel.txt")" == 'previous release' ]]

print 'PASS: staged Universal 2 build preserves the previous release on architecture failure'
