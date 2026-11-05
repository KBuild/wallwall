// SPDX-License-Identifier: GPL-3.0-only
import AppKit
import CoreGraphics

@MainActor
@objc(WWDesktopHost)
public final class WallwallDesktopHost: NSObject {
    @objc public static let shared = WallwallDesktopHost()
    private weak var window: NSWindow?
    private var savedLevel = NSWindow.Level.normal
    private var savedBehavior: NSWindow.CollectionBehavior = []
    private var savedStyle: NSWindow.StyleMask = []
    private var savedFrame = NSRect.zero
    private var savedIgnoresMouse = false
    private var interactive = false
    private var sleeping = false
    private var selectedDisplay: NSNumber?
    private var status: NSStatusItem?
    private var modeItem: NSMenuItem?
    private var displayMenu: NSMenu?
    private var pointerItems: [NSMenuItem] = []
    private var dwellItems: [NSMenuItem] = []
    private var dwellRoot: NSMenuItem?
    private var intervalItems: [NSMenuItem] = []
    private var countItems: [NSMenuItem] = []
    private var fallbackItem: NSMenuItem?
    private var escapeMonitor: Any?
    private var settings: WallwallSettings?
    private var pointer: WallwallPointer?
    private var fallback: WallwallFallback?

    private func displayID(_ screen: NSScreen?) -> NSNumber? {
        screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    }
    private func displayUUID(_ screen: NSScreen) -> String? {
        guard let id = displayID(screen), let uuid = CGDisplayCreateUUIDFromDisplayID(id.uint32Value)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String?
    }
    private func targetScreen() -> NSScreen? {
        NSScreen.screens.first { displayID($0) == selectedDisplay } ?? window?.screen ?? NSScreen.main ?? NSScreen.screens.first
    }
    private func refreshDisplayMenu() {
        displayMenu?.removeAllItems()
        for screen in NSScreen.screens {
            guard let id = displayID(screen) else { continue }
            let item = makeItem(screen.localizedName, action: #selector(selectDisplay), tag: id.intValue)
            item.state = id == selectedDisplay ? .on : .off
            displayMenu?.addItem(item)
        }
    }
    private func refreshDisplaySelection() {
        let screens = NSScreen.screens.filter { displayID($0) != nil }
        selectedDisplay = WallwallDisplaySelection.choose(ids: screens.compactMap { displayID($0) },
            uuids: screens.map { displayUUID($0) ?? "" },
            preferred: UserDefaults.standard.string(forKey: "WWInteractiveDisplayUUID"), fallback: displayID(targetScreen()))
        pointer?.resetHold()
        refreshDisplayMenu()
    }
    private func refreshPointerMenu() {
        guard let settings else { return }
        for item in pointerItems { item.state = item.tag == settings.pointerMode ? .on : .off }
        for item in dwellItems { item.state = item.tag == settings.dwellMilliseconds ? .on : .off }
        dwellRoot?.isEnabled = settings.pointerMode == 0
    }
    private func refreshAmbientMenu() {
        guard let settings else { return }
        for item in intervalItems { item.state = item.tag == settings.ambientIntervalSeconds ? .on : .off }
        for item in countItems { item.state = item.tag == settings.ambientCount ? .on : .off }
    }

    @objc public func configure() -> Int32 {
        // Keep the existing Unity window through temporary visibility and Spaces changes.
        if window != nil { return 1 }
        guard let player = NSApp.windows.filter({ candidate in
            candidate.isVisible && candidate.screen != nil && !(candidate is NSPanel) &&
                candidate.identifier?.rawValue != "WALLWALL.MP4Fallback"
        }).max(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }) else { return 0 }
        restore()
        window = player
        savedLevel = player.level
        savedBehavior = player.collectionBehavior
        savedStyle = player.styleMask
        savedFrame = player.frame
        savedIgnoresMouse = player.ignoresMouseEvents
        selectedDisplay = displayID(player.screen)
        refreshDisplaySelection()
        installControls()
        applyWindow(raise: true)
        reconcileFallback()
        NSLog("WALLWALL desktop configured")
        return 1
    }

    private func applyWindow(raise: Bool) {
        guard let window else { return }
        if interactive {
            if window.styleMask != savedStyle { window.styleMask = savedStyle }
            if window.collectionBehavior != savedBehavior { window.collectionBehavior = savedBehavior }
            if window.level != savedLevel { window.level = savedLevel }
            window.ignoresMouseEvents = false
            if window.frame != savedFrame { window.setFrame(savedFrame, display: true) }
            if raise { NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil) }
        } else {
            if window.styleMask != .borderless { window.styleMask = .borderless }
            let behavior = savedBehavior.subtracting(.managed).union([.canJoinAllSpaces, .stationary])
            if window.collectionBehavior != behavior { window.collectionBehavior = behavior }
            let level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)
            if window.level != level { window.level = level }
            window.ignoresMouseEvents = true
            if let screen = targetScreen(), window.frame != screen.frame { window.setFrame(screen.frame, display: true) }
            if raise { window.orderFront(nil) }
        }
        modeItem?.title = interactive ? "Return to Wallpaper Mode (Esc)" : "Interaction Mode"
    }
    private func reconcileFallback() {
        fallback?.reconcile(unityWindow: window, sleeping: sleeping)
        let count = fallback?.windowCount ?? 0
        fallbackItem?.title = "MP4 fallback: \(count) display\(count == 1 ? "" : "s") (video only; no interaction)"
    }
    private func setInteractive(_ value: Bool) {
        guard interactive != value else { return }
        interactive = value
        if value { pointer?.resetHold() }
        pointer?.interactive = value
        applyWindow(raise: true)
        reconcileFallback()
    }
    @objc public func restore() {
        fallback?.stop()
        fallback = nil
        if let window {
            if window.styleMask != savedStyle { window.styleMask = savedStyle }
            if window.collectionBehavior != savedBehavior { window.collectionBehavior = savedBehavior }
            if window.level != savedLevel { window.level = savedLevel }
            window.ignoresMouseEvents = savedIgnoresMouse
            if window.frame != savedFrame { window.setFrame(savedFrame, display: true) }
        }
        window = nil
        interactive = false
        sleeping = false
        pointer?.stop()
        pointer = nil
        selectedDisplay = nil
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        escapeMonitor = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        if let status { NSStatusBar.system.removeStatusItem(status) }
        status = nil
        settings = nil
        modeItem = nil
        displayMenu = nil
        pointerItems = []
        dwellItems = []
        intervalItems = []
        countItems = []
        dwellRoot = nil
        fallbackItem = nil
    }

    @objc private func toggle(_ sender: Any?) { setInteractive(!interactive) }
    @objc private func quit(_ sender: Any?) { NSApp.terminate(nil) }
    @objc private func selectDisplay(_ sender: NSMenuItem) {
        guard let screen = NSScreen.screens.first(where: { displayID($0)?.intValue == sender.tag }) else { return }
        selectedDisplay = displayID(screen)
        if let uuid = displayUUID(screen) { UserDefaults.standard.set(uuid, forKey: "WWInteractiveDisplayUUID") }
        pointer?.resetHold()
        fallback?.stop()
        if interactive { setInteractive(false) }
        else { applyWindow(raise: true); reconcileFallback() }
        refreshDisplayMenu()
    }
    @objc private func selectPointerMode(_ sender: NSMenuItem) {
        settings?.updatePointerMode(sender.tag)
        pointer?.resetHold()
        pointer?.mode = settings?.pointerMode ?? 0
        refreshPointerMenu()
    }
    @objc private func selectDwell(_ sender: NSMenuItem) {
        settings?.updateDwell(sender.tag)
        refreshPointerMenu()
    }
    @objc private func selectInterval(_ sender: NSMenuItem) {
        settings?.updateInterval(sender.tag)
        refreshAmbientMenu()
    }
    @objc private func selectCount(_ sender: NSMenuItem) {
        settings?.updateCount(sender.tag)
        refreshAmbientMenu()
    }
    @objc private func refresh(_ notification: Notification) {
        if notification.name == NSWorkspace.willSleepNotification || notification.name == NSWorkspace.screensDidSleepNotification {
            sleeping = true
            reconcileFallback()
            return
        }
        if notification.name == NSWorkspace.didWakeNotification || notification.name == NSWorkspace.screensDidWakeNotification { sleeping = false }
        if notification.name == NSApplication.didChangeScreenParametersNotification { refreshDisplaySelection() }
        if window?.isVisible == true { applyWindow(raise: false) }
        reconcileFallback()
    }
    private func makeItem(_ title: String, action: Selector?, tag: Int = 0) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.tag = tag
        return item
    }
    private func addChoices(to menu: NSMenu, title: String, values: [(Int, String)], action: Selector) -> (NSMenuItem, [NSMenuItem]) {
        let root = makeItem(title, action: nil)
        let submenu = NSMenu(title: title)
        let items = values.map { makeItem($0.1, action: action, tag: $0.0) }
        for item in items { submenu.addItem(item) }
        root.submenu = submenu
        menu.addItem(root)
        return (root, items)
    }
    private func installControls() {
        guard status == nil else { return }
        settings = WallwallSettings()
        pointer = WallwallPointer()
        fallback = WallwallFallback()
        pointer?.window = window
        pointer?.mode = settings?.pointerMode ?? 0
        pointer?.interactive = interactive
        let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.status = status
        status.button?.title = "WW"
        status.button?.toolTip = "WALLWALL controls"
        let menu = NSMenu()
        let displayRoot = makeItem("Interactive Display", action: nil)
        displayMenu = NSMenu()
        displayRoot.submenu = displayMenu
        refreshDisplayMenu()
        menu.addItem(displayRoot)
        modeItem = makeItem("Interaction Mode", action: #selector(toggle))
        if let modeItem { menu.addItem(modeItem) }
        menu.addItem(.separator())
        (_, pointerItems) = addChoices(to: menu, title: "Pointer Trigger",
            values: [(0, "Hover after dwell"), (1, "Drag while held")], action: #selector(selectPointerMode))
        let dwell = addChoices(to: menu, title: "Hover Dwell",
            values: [1000, 3000, 5000, 10000].map { ($0, "\($0 / 1000) second\($0 == 1000 ? "" : "s")") }, action: #selector(selectDwell))
        dwellRoot = dwell.0
        dwellItems = dwell.1
        refreshPointerMenu()
        menu.addItem(.separator())
        (_, intervalItems) = addChoices(to: menu, title: "Random Interval",
            values: [300, 600, 1200, 1800].map { ($0, "\($0 / 60) minutes") }, action: #selector(selectInterval))
        (_, countItems) = addChoices(to: menu, title: "Random Plays per Interval",
            values: [0, 3, 5, 10].map { ($0, $0 == 0 ? "Off" : "\($0) plays") }, action: #selector(selectCount))
        refreshAmbientMenu()
        menu.addItem(.separator())
        let fallbackItem = makeItem("MP4 fallback: 0 displays (video only; no interaction)", action: nil)
        fallbackItem.isEnabled = false
        self.fallbackItem = fallbackItem
        menu.addItem(fallbackItem)
        menu.addItem(.separator())
        menu.addItem(makeItem("Quit WALLWALL", action: #selector(quit)))
        status.menu = menu
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if let self, self.interactive && event.keyCode == 53 { self.setInteractive(false); return nil }
            return event
        }
        if pointer?.start() != true { NSLog("WALLWALL global mouse monitor unavailable") }
        NSLog("WALLWALL settings initialized")
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.willSleepNotification,
                     NSWorkspace.didWakeNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refresh), name: name, object: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    @objc public var isInteractive: Int32 { window != nil && interactive ? 1 : 0 }
    @objc public var pointerMode: Int32 { Int32(settings?.pointerMode ?? 0) }
    @objc public var dwellMilliseconds: Int32 { Int32(settings?.dwellMilliseconds ?? 3000) }
    @objc public var ambientIntervalSeconds: Int32 { Int32(settings?.ambientIntervalSeconds ?? 600) }
    @objc public var ambientCount: Int32 { Int32(settings?.ambientCount ?? 5) }
    @objc public var pointerUnobscured: Int32 { pointer?.isDesktopPoint(NSEvent.mouseLocation) == true ? 1 : 0 }
    @objc public var frameRate: Int32 {
        WallwallRenderPolicy.frameCap(sleeping: sleeping,
            visible: window?.isVisible == true && window?.occlusionState.contains(.visible) == true,
            lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled)
    }
    @objc(readCursorX:y:)
    public func readCursor(x: UnsafeMutablePointer<Float>, y: UnsafeMutablePointer<Float>) -> Int32 {
        x.pointee = 0; y.pointee = 0
        guard let point = pointer?.cursor() else { return 0 }
        x.pointee = Float(point.x); y.pointee = Float(point.y)
        return 1
    }
    @objc(readDragHeld:downRevision:upRevision:downX:downY:upX:upY:)
    public func readDrag(held: UnsafeMutablePointer<Int32>, downRevision: UnsafeMutablePointer<UInt32>,
                         upRevision: UnsafeMutablePointer<UInt32>, downX: UnsafeMutablePointer<Float>,
                         downY: UnsafeMutablePointer<Float>, upX: UnsafeMutablePointer<Float>, upY: UnsafeMutablePointer<Float>) -> Int32 {
        guard let pointer, let (down, up) = pointer.dragPoints() else { return 0 }
        held.pointee = pointer.drag.held ? 1 : 0
        downRevision.pointee = pointer.drag.downRevision
        upRevision.pointee = pointer.drag.upRevision
        downX.pointee = Float(down.x); downY.pointee = Float(down.y)
        upX.pointee = Float(up.x); upY.pointee = Float(up.y)
        return 1
    }
}
