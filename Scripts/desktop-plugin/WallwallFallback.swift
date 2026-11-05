// SPDX-License-Identifier: GPL-3.0-only
import AppKit
import AVFoundation

@MainActor
private final class FallbackWindow: NSObject {
    let window: NSWindow
    let player: AVQueuePlayer
    let looper: AVPlayerLooper
    var sleeping = false

    init(screen: NSScreen, video: URL) {
        window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.identifier = NSUserInterfaceItemIdentifier("WALLWALL.MP4Fallback")
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true
        window.hidesOnDeactivate = false
        window.isOpaque = true
        window.backgroundColor = .black
        window.contentView?.wantsLayer = true
        player = AVQueuePlayer(items: [])
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: video))
        super.init()
        let layer = AVPlayerLayer(player: player)
        layer.frame = window.contentView?.bounds ?? .zero
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer.videoGravity = .resizeAspectFill
        window.contentView?.layer?.addSublayer(layer)
        window.orderFront(nil)
        NotificationCenter.default.addObserver(self, selector: #selector(occlusionChanged),
            name: NSWindow.didChangeOcclusionStateNotification, object: window)
    }

    func updatePlayback() {
        let visible = WallwallRenderPolicy.shouldPlay(sleeping: sleeping,
            visible: window.isVisible && window.occlusionState.contains(.visible))
        if visible { if player.rate == 0 { player.play() } }
        else if player.rate != 0 { player.pause() }
    }

    @objc private func occlusionChanged(_ notification: Notification) { updatePlayback() }
    deinit { NotificationCenter.default.removeObserver(self) }

    func stop() {
        NotificationCenter.default.removeObserver(self)
        player.pause()
        looper.disableLooping()
        window.orderOut(nil)
        window.close()
    }
}

@MainActor
final class WallwallFallback {
    private var windows: [NSNumber: FallbackWindow] = [:]
    private var cachedVideo: URL?
    private var reportedMissingVideo = false
    var windowCount: Int { windows.count }

    private func videoURL() -> URL? {
        if let cachedVideo { return cachedVideo }
        let url = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("WALLWALL.mp4")
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            if !reportedMissingVideo { NSLog("WALLWALL MP4 fallback unavailable") }
            reportedMissingVideo = true
            return nil
        }
        cachedVideo = url
        return url
    }

    func reconcile(unityWindow: NSWindow?, sleeping: Bool) {
        guard let unityWindow, unityWindow.isVisible,
              let unityID = unityWindow.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let video = videoURL() else { stop(); return }
        var wanted = Set<NSNumber>()
        for screen in NSScreen.screens {
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  id != unityID else { continue }
            wanted.insert(id)
            let fallback: FallbackWindow
            if let existing = windows[id] {
                fallback = existing
                if fallback.window.frame != screen.frame { fallback.window.setFrame(screen.frame, display: true) }
                if !fallback.window.isVisible { fallback.window.orderFront(nil) }
            } else {
                fallback = FallbackWindow(screen: screen, video: video)
                windows[id] = fallback
            }
            fallback.sleeping = sleeping
            fallback.updatePlayback()
        }
        for id in Array(windows.keys) where !wanted.contains(id) {
            windows.removeValue(forKey: id)?.stop()
        }
    }

    func stop() {
        for fallback in windows.values { fallback.stop() }
        windows.removeAll()
    }
}
