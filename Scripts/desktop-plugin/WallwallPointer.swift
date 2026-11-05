// SPDX-License-Identifier: GPL-3.0-only
import AppKit
import CoreGraphics

@MainActor
final class WallwallPointer {
    weak var window: NSWindow?
    var interactive = false {
        didSet {
            guard interactive != oldValue else { return }
            if interactive { resetHold() }
            refreshMonitor()
        }
    }
    var mode = 0 {
        didSet {
            guard mode != oldValue else { return }
            resetHold()
            refreshMonitor()
        }
    }
    private var monitor: Any?
    let drag = WallwallDragState()

    private func refreshMonitor() {
        guard !interactive, mode == 1, window != nil else {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            return
        }
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
            guard let self, let window = self.window else { return }
            let point = NSEvent.mouseLocation
            if event.type == .leftMouseDown {
                self.drag.press(at: point, accepted: NSPointInRect(point, window.frame) && self.isDesktopPoint(point))
            } else if event.type == .leftMouseUp {
                self.drag.release(at: point)
            }
        }
    }

    func start() -> Bool {
        refreshMonitor()
        return mode != 1 || interactive || monitor != nil
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        window = nil
        resetHold()
    }

    func resetHold() { drag.release(at: NSEvent.mouseLocation) }

    static func normalized(_ point: NSPoint, in frame: NSRect) -> NSPoint? {
        guard frame.width > 0, frame.height > 0 else { return nil }
        return NSPoint(x: (point.x - frame.origin.x) / frame.width,
                       y: (point.y - frame.origin.y) / frame.height)
    }

    func cursor() -> NSPoint? {
        guard let window, !interactive else { return nil }
        return Self.normalized(NSEvent.mouseLocation, in: window.frame)
    }

    func dragPoints() -> (NSPoint, NSPoint)? {
        guard let window, !interactive, mode == 1, monitor != nil,
              let down = Self.normalized(drag.downPoint, in: window.frame),
              let up = Self.normalized(drag.upPoint, in: window.frame) else { return nil }
        return (down, up)
    }

    func isDesktopPoint(_ point: NSPoint) -> Bool {
        guard let window, NSPointInRect(point, window.frame),
              let entries = CGWindowListCopyWindowInfo(.optionOnScreenAboveWindow,
                  CGWindowID(window.windowNumber)) as? [[String: Any]] else { return false }
        let cgPoint = CGPoint(x: point.x, y: CGDisplayBounds(CGMainDisplayID()).height - point.y)
        for entry in entries {
            let layer = (entry[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
            if layer < 0 || layer == CGWindowLevelForKey(.cursorWindow) { continue }
            let alpha = (entry[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 0
            guard alpha > 0.01,
                  let bounds = entry[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds), rect.contains(cgPoint) else { continue }
            // Preserve the full-display Dock-host exception without ignoring ordinary Dock windows.
            if layer == CGWindowLevelForKey(.dockWindow),
               let pid = entry[kCGWindowOwnerPID as String] as? NSNumber,
               NSRunningApplication(processIdentifier: pid.int32Value)?.bundleIdentifier == "com.apple.dock",
               NSScreen.screens.contains(where: { screen in
                   guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
                   return rect == CGDisplayBounds(id.uint32Value)
               }) { continue }
            return false
        }
        return true
    }
}
