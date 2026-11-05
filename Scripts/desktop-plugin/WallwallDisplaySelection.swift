// SPDX-License-Identifier: GPL-3.0-only
import Foundation

@objc(WWDisplaySelection)
public final class WallwallDisplaySelection: NSObject {
    @objc(chooseFrom:uuids:preferred:fallback:)
    public static func choose(ids: [NSNumber], uuids: [String], preferred: String?, fallback: NSNumber?) -> NSNumber? {
        if let preferred, let index = uuids.firstIndex(of: preferred), ids.indices.contains(index) {
            return ids[index]
        }
        if let fallback, ids.contains(fallback) { return fallback }
        return ids.first
    }
}
