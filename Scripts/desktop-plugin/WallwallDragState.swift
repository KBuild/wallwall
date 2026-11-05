// SPDX-License-Identifier: GPL-3.0-only
import Foundation

@objc(WWDragState)
public final class WallwallDragState: NSObject {
    @objc public private(set) var held = false
    @objc public private(set) var downRevision: UInt32 = 0
    @objc public private(set) var upRevision: UInt32 = 0
    @objc public private(set) var downPoint = NSPoint(x: 0, y: 0)
    @objc public private(set) var upPoint = NSPoint(x: 0, y: 0)

    @objc(pressAt:accepted:)
    public func press(at point: NSPoint, accepted: Bool) {
        held = accepted
        if accepted {
            downPoint = point
            downRevision &+= 1
        }
    }
    @objc(releaseAt:)
    public func release(at point: NSPoint) {
        guard held else { return }
        held = false
        upPoint = point
        upRevision &+= 1
    }
}
