.PHONY: test build run live-check clean

test:
	zsh Scripts/test.sh

build: test
	zsh Scripts/build.command

run: build
	open 'build/Quota Rings.app'

live-check:
	mkdir -p build
	swiftc -swift-version 5 -module-cache-path build/module-cache Sources/QuotaModel.swift Sources/QuotaHistory.swift Sources/QuotaForecast.swift Sources/TaskStatus.swift Sources/WidgetPreferences.swift Sources/WidgetVisibility.swift Sources/CodexLocator.swift Sources/QuotaConnectionState.swift Sources/QuotaClient.swift Sources/QuotaView.swift Tests/LiveCheck.swift -o build/live-check
	build/live-check build/live-preview.png

clean:
	rm -rf build
