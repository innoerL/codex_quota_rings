import CoreGraphics

@main struct WidgetPlacementResolverTests {
    static func main() {
        let screen = CGRect(x: 0, y: 0, width: 500, height: 400)
        let codex = CGRect(x: 150, y: 100, width: 180, height: 180)
        let size = CGSize(width: 40, height: 60)
        func panel(_ x: CGFloat, _ y: CGFloat) -> CGRect { CGRect(origin: CGPoint(x: x, y: y), size: size) }
        func samePoint(_ left: CGPoint, _ right: CGPoint) -> Bool {
            left.x == right.x && left.y == right.y
        }
        func sameFrame(_ left: CGRect, _ right: CGRect) -> Bool {
            samePoint(left.origin, right.origin) && left.size.width == right.size.width && left.size.height == right.size.height
        }
        func resolve(_ frame: CGRect, occupied: [CGRect] = []) -> CGRect {
            WidgetPlacementResolver.resolve(panelFrame: frame, screenFrame: screen, codexFrames: [codex], occupiedFrames: occupied)
        }

        precondition(samePoint(resolve(panel(112, 160)).origin, CGPoint(x: 102, y: 160)), "left edge must snap with an 8-point gap")
        precondition(samePoint(resolve(panel(338, 160)).origin, CGPoint(x: 338, y: 160)), "right edge must snap with an 8-point gap")
        precondition(samePoint(resolve(panel(210, 288)).origin, CGPoint(x: 210, y: 288)), "top edge must snap with an 8-point gap")
        precondition(samePoint(resolve(panel(210, 32)).origin, CGPoint(x: 210, y: 32)), "bottom edge must snap with an 8-point gap")
        precondition(sameFrame(resolve(panel(65, 0)), panel(65, 0)), "a drag farther than 28 points must not snap")

        let corner = resolve(panel(112, 285))
        precondition(samePoint(corner.origin, CGPoint(x: 112, y: 288)), "a corner drag must choose the least-movement candidate")

        let movedAroundWindow = resolve(panel(112, 160), occupied: [CGRect(x: 90, y: 140, width: 80, height: 100)])
        precondition(!movedAroundWindow.intersects(CGRect(x: 90, y: 140, width: 80, height: 100)), "a snapped widget must slide along an edge around a window")

        let noInterval = resolve(panel(112, 160), occupied: [CGRect(x: 90, y: 0, width: 80, height: 400)])
        precondition(sameFrame(noInterval, panel(112, 160)), "a fully blocked edge must reject its snap candidate")

        let clampedScreen = CGRect(x: 0, y: 0, width: 260, height: 200)
        let clamped = WidgetPlacementResolver.resolve(panelFrame: panel(232, 150), screenFrame: clampedScreen,
                                                       codexFrames: [CGRect(x: 220, y: 20, width: 30, height: 160)], occupiedFrames: [])
        precondition(clamped.maxX <= clampedScreen.maxX && clamped.maxY <= clampedScreen.maxY,
                     "resolved frames must remain inside the Dock-safe screen frame")
        print("PASS: drag-end snapping, avoidance, clamping, and fallback")
    }
}
