import AppKit

@main struct LiveCheck {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let client = QuotaClient()
        let view = QuotaView(frame: NSRect(origin: .zero, size: QuotaView.preferredSize))
        var first: Date?
        client.onChange = { snapshot, error in
            if let error { fputs("Live read: \(error)\n", stderr); return }
            guard let snapshot else { return }
            guard snapshot.fiveHour?.remainingPercent != nil, snapshot.week?.remainingPercent != nil else {
                fputs("FAIL: expected the signed-in account's two quota windows\n", stderr)
                client.stop(); exit(1)
            }
            view.snapshot = snapshot
            view.connectionError = nil
            if first == nil {
                first = Date()
                print("PASS: first live quota read (values kept private)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { client.refresh() }
            } else if Date().timeIntervalSince(first!) >= 2 {
                let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
                view.cacheDisplay(in: view.bounds, to: bitmap)
                let path = CommandLine.arguments[1]
                try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
                print("PASS: second live read and native view rendered to \(path)")
                client.stop(); exit(0)
            }
        }
        client.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 50) {
            fputs("FAIL: live refresh timed out\n", stderr); client.stop(); exit(1)
        }
        app.run()
    }
}
