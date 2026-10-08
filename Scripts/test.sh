#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h:h}"
quota_test_dir=$(mktemp -d "${TMPDIR:-/tmp}/quota-rings-tests.XXXXXX")
trap 'rm -rf "$quota_test_dir"' EXIT
quota_cache="${TMPDIR:-/tmp}/codex-quota-rings/module-cache"
mkdir -p "$quota_cache" build
# Web uploads and some ZIP extractors do not preserve executable mode bits.
chmod +x Tests/fake-codex.py
compile() { swiftc -swift-version 5 -module-cache-path "$quota_cache" "$@"; }
compile Sources/QuotaModel.swift Tests/ModelTests.swift -o "$quota_test_dir/model"
"$quota_test_dir/model"
compile Sources/QuotaModel.swift Sources/QuotaClient.swift Tests/ProtocolTests.swift -o "$quota_test_dir/protocol"
"$quota_test_dir/protocol" "$PWD/Tests/fake-codex.py"
compile Sources/WidgetPreferences.swift Tests/WidgetPreferencesTests.swift -o "$quota_test_dir/preferences"
"$quota_test_dir/preferences"
compile Sources/WidgetPreferences.swift Sources/WidgetVisibility.swift Tests/VisibilityTests.swift -o "$quota_test_dir/visibility"
"$quota_test_dir/visibility"
compile Sources/WidgetPreferences.swift Sources/WidgetMenu.swift Tests/MenuTests.swift -o "$quota_test_dir/menu"
"$quota_test_dir/menu"
quota_view_sources=(Sources/QuotaModel.swift Sources/WidgetPreferences.swift Sources/QuotaView.swift Sources/QuotaDetailsView.swift Sources/LargeQuotaView.swift)
compile "${quota_view_sources[@]}" Tests/AppearanceCheck.swift -o "$quota_test_dir/appearance"
"$quota_test_dir/appearance" "$PWD/build/detail-preview.png"
compile "${quota_view_sources[@]}" Tests/LayoutTests.swift -o "$quota_test_dir/layout"
"$quota_test_dir/layout" "$PWD/build/layout-preview.png"
compile -D QUOTA_TEST Sources/*.swift Tests/ControllerTests.swift -o "$quota_test_dir/controller"
"$quota_test_dir/controller" "$PWD/Tests/fake-codex.py" | tee "$quota_test_dir/controller-result"
# AppKit can exit early in a headless or restricted session; exit 0 alone is insufficient.
grep -q '^PASS: real panels' "$quota_test_dir/controller-result" || { print -u2 'FAIL: controller tests require a macOS graphical session'; exit 1; }
zsh Tests/PublicTreeCheck.sh
zsh Scripts/check-public-tree.sh
