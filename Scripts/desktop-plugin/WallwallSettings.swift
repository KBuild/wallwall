// SPDX-License-Identifier: GPL-3.0-only
import Foundation

@objc(WWSettings)
public final class WallwallSettings: NSObject {
    private let defaults: UserDefaults
    private var storedPointerMode: Int
    @objc public var pointerMode: Int { storedPointerMode }
    private var storedDwellMilliseconds: Int
    @objc public var dwellMilliseconds: Int { storedDwellMilliseconds }
    private var storedAmbientIntervalSeconds: Int
    @objc public var ambientIntervalSeconds: Int { storedAmbientIntervalSeconds }
    private var storedAmbientCount: Int
    @objc public var ambientCount: Int { storedAmbientCount }

    @objc public override convenience init() { self.init(defaults: .standard) }

    @objc(initWithDefaults:)
    public init(defaults: UserDefaults) {
        self.defaults = defaults
        func read(_ key: String, _ allowed: [Int], _ fallback: Int) -> Int {
            let value = defaults.integer(forKey: key)
            return defaults.object(forKey: key) != nil && allowed.contains(value) ? value : fallback
        }
        storedPointerMode = read("WWPointerMode", [0, 1], 0)
        storedDwellMilliseconds = read("WWDwellMilliseconds", [1000, 3000, 5000, 10000], 3000)
        storedAmbientIntervalSeconds = read("WWAmbientIntervalSeconds", [300, 600, 1200, 1800], 600)
        storedAmbientCount = read("WWAmbientCount", [0, 3, 5, 10], 5)
        super.init()
    }

    @objc(setPointerMode:)
    public func updatePointerMode(_ value: Int) {
        guard [0, 1].contains(value) else { return }
        storedPointerMode = value
        defaults.set(value, forKey: "WWPointerMode")
    }
    @objc(setDwellMilliseconds:)
    public func updateDwell(_ value: Int) {
        guard [1000, 3000, 5000, 10000].contains(value) else { return }
        storedDwellMilliseconds = value
        defaults.set(value, forKey: "WWDwellMilliseconds")
    }
    @objc(setAmbientIntervalSeconds:)
    public func updateInterval(_ value: Int) {
        guard [300, 600, 1200, 1800].contains(value) else { return }
        storedAmbientIntervalSeconds = value
        defaults.set(value, forKey: "WWAmbientIntervalSeconds")
    }
    @objc(setAmbientCount:)
    public func updateCount(_ value: Int) {
        guard [0, 3, 5, 10].contains(value) else { return }
        storedAmbientCount = value
        defaults.set(value, forKey: "WWAmbientCount")
    }
}
