// SPDX-License-Identifier: GPL-3.0-only
import AppKit

@main
struct HostStateTests {
    @MainActor static func main() {
        let frame = NSRect(x: -200, y: 100, width: 400, height: 200)
        precondition(WallwallPointer.normalized(NSPoint(x: 0, y: 200), in: frame) == NSPoint(x: 0.5, y: 0.5))
        precondition(WallwallPointer.normalized(NSPoint(x: -200, y: 100), in: frame) == .zero)
        precondition(WallwallPointer.normalized(.zero, in: .zero) == nil)
        let pointer = WallwallPointer()
        precondition(pointer.cursor() == nil && pointer.dragPoints() == nil)
        precondition(!pointer.isDesktopPoint(.zero))
        pointer.drag.press(at: .zero, accepted: true)
        pointer.mode = 1
        precondition(!pointer.drag.held && pointer.drag.upRevision == 1)
        pointer.drag.press(at: .zero, accepted: true)
        pointer.interactive = true
        precondition(!pointer.drag.held && pointer.drag.upRevision == 2)
        pointer.drag.press(at: .zero, accepted: true)
        pointer.stop()
        precondition(!pointer.drag.held && pointer.drag.upRevision == 3)
        pointer.stop()
        precondition(pointer.drag.upRevision == 3)
        let fallback = WallwallFallback()
        fallback.reconcile(unityWindow: nil, sleeping: false)
        fallback.stop()
        precondition(fallback.windowCount == 0)
        print("Swift pointer normalization, mode reset and fallback lifecycle checks passed")
    }
}
