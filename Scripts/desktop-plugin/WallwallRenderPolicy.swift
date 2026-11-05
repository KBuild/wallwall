// SPDX-License-Identifier: GPL-3.0-only
import Foundation

@objc(WWRenderPolicy)
public final class WallwallRenderPolicy: NSObject {
    @objc(shouldPlayWithSleeping:visible:)
    public static func shouldPlay(sleeping: Bool, visible: Bool) -> Bool {
        return !sleeping && visible
    }
    @objc(frameCapWithSleeping:visible:lowPower:)
    public static func frameCap(sleeping: Bool, visible: Bool, lowPower: Bool) -> Int32 {
        guard shouldPlay(sleeping: sleeping, visible: visible) else { return 2 }
        return lowPower ? 15 : 30
    }
}
