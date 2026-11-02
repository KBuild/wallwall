// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import "WallwallSettings.h"
#import "WallwallPointer.h"
#import "WallwallFallback.h"
#include <stdint.h>

// Unity may call the C ABI from a worker thread; all AppKit work uses main.
static __weak NSWindow *sWindow;
static NSWindowLevel sLevel;
static NSWindowCollectionBehavior sBehavior;
static NSWindowStyleMask sStyle;
static NSRect sFrame;
static BOOL sIgnoresMouse, sInteractive, sSleeping;
static NSNumber *sDisplay;
static NSStatusItem *sStatus;
static NSMenuItem *sModeItem;
static NSArray<NSMenuItem *> *sPointerModeItems;
static NSArray<NSMenuItem *> *sDwellItems;
static NSMenuItem *sDwellRoot;
static NSArray<NSMenuItem *> *sAmbientIntervalItems;
static NSArray<NSMenuItem *> *sAmbientCountItems;
static id sEscapeMonitor;
static WWSettings *sSettings;
static WWPointer *sPointer;
static WWFallback *sFallback;
static NSMenuItem *sFallbackItem;

@interface WWDesktopActions : NSObject
- (void)toggle:(id)sender;
- (void)selectDisplay:(NSMenuItem *)sender;
- (void)selectPointerMode:(NSMenuItem *)sender;
- (void)selectDwell:(NSMenuItem *)sender;
- (void)selectAmbientInterval:(NSMenuItem *)sender;
- (void)selectAmbientCount:(NSMenuItem *)sender;
- (void)quit:(id)sender;
- (void)refresh:(NSNotification *)notification;
@end
static WWDesktopActions *sActions;

static NSNumber *DisplayID(NSScreen *screen) { return screen.deviceDescription[@"NSScreenNumber"]; }

static NSString *DisplayUUID(NSScreen *screen)
{
    CFUUIDRef uuid = CGDisplayCreateUUIDFromDisplayID(DisplayID(screen).unsignedIntValue);
    if (!uuid) return nil;
    NSString *value = CFBridgingRelease(CFUUIDCreateString(NULL, uuid));
    CFRelease(uuid);
    return value;
}

static void RefreshPointerMenu(void)
{
    for (NSMenuItem *item in sPointerModeItems)
        item.state = item.tag == sSettings.pointerMode ? NSControlStateValueOn : NSControlStateValueOff;
    for (NSMenuItem *item in sDwellItems)
        item.state = item.tag == sSettings.dwellMilliseconds ? NSControlStateValueOn : NSControlStateValueOff;
    sDwellRoot.enabled = sSettings.pointerMode == 0;
}

static void RefreshAmbientMenu(void)
{
    for (NSMenuItem *item in sAmbientIntervalItems)
        item.state = item.tag == sSettings.ambientIntervalSeconds ? NSControlStateValueOn : NSControlStateValueOff;
    for (NSMenuItem *item in sAmbientCountItems)
        item.state = item.tag == sSettings.ambientCount ? NSControlStateValueOn : NSControlStateValueOff;
}

static NSScreen *TargetScreen(void)
{
    for (NSScreen *screen in NSScreen.screens)
        if ([DisplayID(screen) isEqual:sDisplay]) return screen;
    return sWindow.screen ?: NSScreen.mainScreen ?: NSScreen.screens.firstObject;
}

static NSWindow *FindPlayerWindow(void)
{
    NSWindow *best = nil;
    CGFloat area = 0;
    for (NSWindow *window in NSApp.windows) {
        if (!window.isVisible || !window.screen || [window isKindOfClass:NSPanel.class] ||
            [window.identifier isEqualToString:@"WALLWALL.MP4Fallback"]) continue;
        CGFloat candidate = window.frame.size.width * window.frame.size.height;
        if (candidate > area) { best = window; area = candidate; }
    }
    return best;
}

static void ApplyWindow(BOOL raise)
{
    NSWindow *window = sWindow;
    if (!window) return;
    if (sInteractive) {
        if (window.styleMask != sStyle) window.styleMask = sStyle;
        if (window.collectionBehavior != sBehavior) window.collectionBehavior = sBehavior;
        if (window.level != sLevel) window.level = sLevel;
        window.ignoresMouseEvents = NO;
        if (!NSEqualRects(window.frame, sFrame)) [window setFrame:sFrame display:YES];
        if (raise) {
            [NSApp activateIgnoringOtherApps:YES];
            [window makeKeyAndOrderFront:nil];
        }
    } else {
        if (window.styleMask != NSWindowStyleMaskBorderless) window.styleMask = NSWindowStyleMaskBorderless;
        NSWindowCollectionBehavior behavior = (sBehavior & ~NSWindowCollectionBehaviorManaged) |
            NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary;
        if (window.collectionBehavior != behavior) window.collectionBehavior = behavior;
        NSWindowLevel level = CGWindowLevelForKey(kCGDesktopIconWindowLevelKey) - 1;
        if (window.level != level) window.level = level;
        window.ignoresMouseEvents = YES;
        NSScreen *screen = TargetScreen();
        if (screen && !NSEqualRects(window.frame, screen.frame))
            [window setFrame:screen.frame display:YES];
        if (raise) [window orderFront:nil];
    }
    sModeItem.title = sInteractive ? @"Return to Wallpaper Mode (Esc)" : @"Interaction Mode";
}

static void ReconcileFallback(void)
{
    [sFallback reconcileWithUnityWindow:sWindow sleeping:sSleeping];
    if (sFallbackItem)
        sFallbackItem.title = [NSString stringWithFormat:
            @"MP4 fallback: %lu display%@ (video only; no interaction)",
            (unsigned long)sFallback.windowCount, sFallback.windowCount == 1 ? @"" : @"s"];
}

static void SetInteractive(BOOL interactive)
{
    if (sInteractive == interactive) return;
    sInteractive = interactive;
    if (interactive) [sPointer resetHold];
    sPointer.interactive = interactive;
    ApplyWindow(YES);
    ReconcileFallback();
    NSLog(@"WALLWALL desktop mode: %@", interactive ? @"interaction" : @"wallpaper");
}

static void RestoreWindow(void)
{
    [sFallback stop];
    sFallback = nil;
    sFallbackItem = nil;
    NSWindow *window = sWindow;
    if (window) {
        if (window.styleMask != sStyle) window.styleMask = sStyle;
        if (window.collectionBehavior != sBehavior) window.collectionBehavior = sBehavior;
        if (window.level != sLevel) window.level = sLevel;
        window.ignoresMouseEvents = sIgnoresMouse;
        if (!NSEqualRects(window.frame, sFrame)) [window setFrame:sFrame display:YES];
    }
    sWindow = nil;
    sInteractive = sSleeping = NO;
    [sPointer stop];
    sPointer = nil;
    sDisplay = nil;
    if (sEscapeMonitor) { [NSEvent removeMonitor:sEscapeMonitor]; sEscapeMonitor = nil; }
    if (sActions) {
        [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:sActions];
        [NSNotificationCenter.defaultCenter removeObserver:sActions];
        sActions = nil;
    }
    if (sStatus) { [NSStatusBar.systemStatusBar removeStatusItem:sStatus]; sStatus = nil; }
    sSettings = nil;
    sModeItem = nil;
    sPointerModeItems = nil;
    sDwellItems = nil;
    sDwellRoot = nil;
    sAmbientIntervalItems = nil;
    sAmbientCountItems = nil;
}

@implementation WWDesktopActions
- (void)toggle:(id)sender { SetInteractive(!sInteractive); }
- (void)selectDisplay:(NSMenuItem *)sender
{
    for (NSScreen *screen in NSScreen.screens) {
        if (DisplayID(screen).integerValue != sender.tag) continue;
        sDisplay = DisplayID(screen);
        NSString *uuid = DisplayUUID(screen);
        if (uuid) [NSUserDefaults.standardUserDefaults setObject:uuid forKey:@"WWInteractiveDisplayUUID"];
        [sPointer resetHold];
        [sFallback stop];
        if (sInteractive) SetInteractive(NO);
        else { ApplyWindow(YES); ReconcileFallback(); }
        for (NSMenuItem *item in sender.menu.itemArray)
            item.state = item == sender ? NSControlStateValueOn : NSControlStateValueOff;
        NSLog(@"WALLWALL interactive display: %@", sDisplay);
        break;
    }
}
- (void)selectPointerMode:(NSMenuItem *)sender
{
    [sSettings setPointerMode:sender.tag];
    [sPointer resetHold];
    sPointer.mode = sSettings.pointerMode;
    RefreshPointerMenu();
    NSLog(@"WALLWALL pointer mode: %@", sSettings.pointerMode == 0 ? @"hover" : @"drag");
}
- (void)selectDwell:(NSMenuItem *)sender
{
    [sSettings setDwellMilliseconds:sender.tag];
    RefreshPointerMenu();
    NSLog(@"WALLWALL hover dwell: %ld ms", (long)sSettings.dwellMilliseconds);
}
- (void)selectAmbientInterval:(NSMenuItem *)sender
{
    [sSettings setAmbientIntervalSeconds:sender.tag];
    RefreshAmbientMenu();
    NSLog(@"WALLWALL ambient interval: %ld s", (long)sSettings.ambientIntervalSeconds);
}
- (void)selectAmbientCount:(NSMenuItem *)sender
{
    [sSettings setAmbientCount:sender.tag];
    RefreshAmbientMenu();
    NSLog(@"WALLWALL ambient count: %ld", (long)sSettings.ambientCount);
}
- (void)quit:(id)sender { [NSApp terminate:nil]; }
- (void)refresh:(NSNotification *)notification
{
    if ([notification.name isEqualToString:NSWorkspaceWillSleepNotification] ||
        [notification.name isEqualToString:NSWorkspaceScreensDidSleepNotification]) {
        sSleeping = YES;
        ReconcileFallback();
        return;
    }
    if ([notification.name isEqualToString:NSWorkspaceDidWakeNotification] ||
        [notification.name isEqualToString:NSWorkspaceScreensDidWakeNotification]) sSleeping = NO;
    if (sWindow && sWindow.isVisible) ApplyWindow(NO);
    ReconcileFallback();
}
@end

static void InstallControls(void)
{
    if (sActions) return;
    sActions = [WWDesktopActions new];
    sSettings = [WWSettings new];
    sPointer = [WWPointer new];
    sFallback = [WWFallback new];
    sPointer.window = sWindow;
    sPointer.mode = sSettings.pointerMode;
    sPointer.interactive = sInteractive;
    sStatus = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    sStatus.button.title = @"WW";
    sStatus.button.toolTip = @"WALLWALL controls";
    NSMenu *menu = [NSMenu new];
    NSMenuItem *displayRoot = [[NSMenuItem alloc] initWithTitle:@"Interactive Display" action:nil keyEquivalent:@""];
    NSMenu *displayMenu = [NSMenu new];
    for (NSScreen *screen in NSScreen.screens) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:screen.localizedName action:@selector(selectDisplay:) keyEquivalent:@""];
        item.tag = DisplayID(screen).integerValue;
        item.target = sActions;
        item.state = [DisplayID(screen) isEqual:sDisplay] ? NSControlStateValueOn : NSControlStateValueOff;
        [displayMenu addItem:item];
    }
    displayRoot.submenu = displayMenu;
    [menu addItem:displayRoot];
    sModeItem = [[NSMenuItem alloc] initWithTitle:@"Interaction Mode" action:@selector(toggle:) keyEquivalent:@""];
    sModeItem.target = sActions;
    [menu addItem:sModeItem];
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *pointerRoot = [[NSMenuItem alloc] initWithTitle:@"Pointer Trigger" action:nil keyEquivalent:@""];
    NSMenu *pointerMenu = [[NSMenu alloc] initWithTitle:@"Pointer Trigger"];
    NSMenuItem *hover = [[NSMenuItem alloc] initWithTitle:@"Hover after dwell" action:@selector(selectPointerMode:) keyEquivalent:@""];
    hover.tag = 0; hover.target = sActions; [pointerMenu addItem:hover];
    NSMenuItem *drag = [[NSMenuItem alloc] initWithTitle:@"Drag while held" action:@selector(selectPointerMode:) keyEquivalent:@""];
    drag.tag = 1; drag.target = sActions; [pointerMenu addItem:drag];
    sPointerModeItems = @[hover, drag];
    pointerRoot.submenu = pointerMenu; [menu addItem:pointerRoot];
    sDwellRoot = [[NSMenuItem alloc] initWithTitle:@"Hover Dwell" action:nil keyEquivalent:@""];
    NSMenu *dwellMenu = [[NSMenu alloc] initWithTitle:@"Hover Dwell"];
    NSMutableArray<NSMenuItem *> *dwellItems = [NSMutableArray array];
    for (NSNumber *milliseconds in @[@1000, @3000, @5000, @10000]) {
        NSString *title = [NSString stringWithFormat:@"%ld second%@", (long)milliseconds.integerValue / 1000,
                           milliseconds.integerValue == 1000 ? @"" : @"s"];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(selectDwell:) keyEquivalent:@""];
        item.tag = milliseconds.integerValue; item.target = sActions;
        [dwellMenu addItem:item]; [dwellItems addObject:item];
    }
    sDwellItems = dwellItems;
    sDwellRoot.submenu = dwellMenu; [menu addItem:sDwellRoot];
    RefreshPointerMenu();
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *ambientIntervalRoot = [[NSMenuItem alloc] initWithTitle:@"Random Interval" action:nil keyEquivalent:@""];
    NSMenu *ambientIntervalMenu = [[NSMenu alloc] initWithTitle:@"Random Interval"];
    NSMutableArray<NSMenuItem *> *intervalItems = [NSMutableArray array];
    for (NSNumber *seconds in @[@300, @600, @1200, @1800]) {
        NSString *title = [NSString stringWithFormat:@"%ld minutes", (long)seconds.integerValue / 60];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(selectAmbientInterval:) keyEquivalent:@""];
        item.tag = seconds.integerValue; item.target = sActions;
        [ambientIntervalMenu addItem:item]; [intervalItems addObject:item];
    }
    sAmbientIntervalItems = intervalItems;
    ambientIntervalRoot.submenu = ambientIntervalMenu; [menu addItem:ambientIntervalRoot];
    NSMenuItem *ambientCountRoot = [[NSMenuItem alloc] initWithTitle:@"Random Plays per Interval" action:nil keyEquivalent:@""];
    NSMenu *ambientCountMenu = [[NSMenu alloc] initWithTitle:@"Random Plays per Interval"];
    NSMutableArray<NSMenuItem *> *countItems = [NSMutableArray array];
    for (NSNumber *count in @[@0, @3, @5, @10]) {
        NSString *title = count.integerValue == 0 ? @"Off" : [NSString stringWithFormat:@"%ld plays", (long)count.integerValue];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(selectAmbientCount:) keyEquivalent:@""];
        item.tag = count.integerValue; item.target = sActions;
        [ambientCountMenu addItem:item]; [countItems addObject:item];
    }
    sAmbientCountItems = countItems;
    ambientCountRoot.submenu = ambientCountMenu; [menu addItem:ambientCountRoot];
    RefreshAmbientMenu();
    [menu addItem:NSMenuItem.separatorItem];
    sFallbackItem = [[NSMenuItem alloc] initWithTitle:@"MP4 fallback: 0 displays (video only; no interaction)"
        action:nil keyEquivalent:@""];
    sFallbackItem.enabled = NO;
    [menu addItem:sFallbackItem];
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:@"Quit WALLWALL" action:@selector(quit:) keyEquivalent:@""];
    quit.target = sActions; [menu addItem:quit];
    sStatus.menu = menu;
    sEscapeMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
        if (sInteractive && event.keyCode == 53) { SetInteractive(NO); return nil; }
        return event;
    }];
    if (![sPointer start]) NSLog(@"WALLWALL global mouse monitor unavailable");
    NSLog(@"WALLWALL settings: pointer=%ld dwell=%ldms ambient=%lds/%ld",
          (long)sSettings.pointerMode, (long)sSettings.dwellMilliseconds,
          (long)sSettings.ambientIntervalSeconds, (long)sSettings.ambientCount);
    NSNotificationCenter *workspace = NSWorkspace.sharedWorkspace.notificationCenter;
    [workspace addObserver:sActions selector:@selector(refresh:) name:NSWorkspaceActiveSpaceDidChangeNotification object:nil];
    [workspace addObserver:sActions selector:@selector(refresh:) name:NSWorkspaceWillSleepNotification object:nil];
    [workspace addObserver:sActions selector:@selector(refresh:) name:NSWorkspaceDidWakeNotification object:nil];
    [workspace addObserver:sActions selector:@selector(refresh:) name:NSWorkspaceScreensDidSleepNotification object:nil];
    [workspace addObserver:sActions selector:@selector(refresh:) name:NSWorkspaceScreensDidWakeNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:sActions selector:@selector(refresh:)
        name:NSApplicationDidChangeScreenParametersNotification object:nil];
}

static int ConfigureOnMain(void)
{
    // Unity polls every two seconds. Reordering each time would disrupt Spaces.
    // Keep the Unity identity through temporary ordering/visibility changes.
    // Rebinding here can mistake the larger MP4 window for the Unity player.
    if (sWindow) return 1;
    NSWindow *window = FindPlayerWindow();
    if (!window) return 0;
    RestoreWindow();
    sWindow = window;
    sLevel = window.level;
    sBehavior = window.collectionBehavior;
    sStyle = window.styleMask;
    sFrame = window.frame;
    sIgnoresMouse = window.ignoresMouseEvents;
    sDisplay = DisplayID(window.screen);
    NSString *preferred = [NSUserDefaults.standardUserDefaults stringForKey:@"WWInteractiveDisplayUUID"];
    for (NSScreen *screen in NSScreen.screens)
        if (preferred && [DisplayUUID(screen) isEqualToString:preferred]) { sDisplay = DisplayID(screen); break; }
    InstallControls();
    ApplyWindow(YES);
    ReconcileFallback();
    NSLog(@"WALLWALL desktop configured: display %@, level %ld, frame %@",
          sDisplay, (long)window.level, NSStringFromRect(window.frame));
    return 1;
}

extern "C" __attribute__((visibility("default"))) int WWDesktopConfigure(void)
{
    if (NSThread.isMainThread) return ConfigureOnMain();
    __block int result = 0;
    dispatch_sync(dispatch_get_main_queue(), ^{ result = ConfigureOnMain(); });
    return result;
}
extern "C" __attribute__((visibility("default"))) int WWDesktopIsInteractive(void)
{
    return sWindow && sInteractive ? 1 : 0;
}
extern "C" __attribute__((visibility("default"))) int WWDesktopPointerMode(void)
{
    return sSettings ? (int)sSettings.pointerMode : 0;
}
extern "C" __attribute__((visibility("default"))) int WWDesktopDwellMilliseconds(void)
{
    return sSettings ? (int)sSettings.dwellMilliseconds : 3000;
}
extern "C" __attribute__((visibility("default"))) int WWDesktopAmbientIntervalSeconds(void)
{
    return sSettings ? (int)sSettings.ambientIntervalSeconds : 600;
}
extern "C" __attribute__((visibility("default"))) int WWDesktopAmbientCount(void)
{
    return sSettings ? (int)sSettings.ambientCount : 5;
}
extern "C" __attribute__((visibility("default"))) int WWDesktopDragState(
    int *held, uint32_t *downRevision, uint32_t *upRevision,
    float *downX, float *downY, float *upX, float *upY)
{
    if (!held || !downRevision || !upRevision || !downX || !downY || !upX || !upY) return 0;
    __block int valid = 0;
    void (^readState)(void) = ^{
        valid = [sPointer readDragHeld:held downRevision:downRevision upRevision:upRevision
                           downX:downX downY:downY upX:upX upY:upY];
    };
    if (NSThread.isMainThread) readState();
    else dispatch_sync(dispatch_get_main_queue(), readState);
    return valid;
}
extern "C" __attribute__((visibility("default"))) void WWDesktopRestore(void)
{
    if (NSThread.isMainThread) RestoreWindow();
    else dispatch_sync(dispatch_get_main_queue(), ^{ RestoreWindow(); });
}

// Normalized Unity coordinates, bottom-left origin. Returns 1 with a window.
// NSEvent.mouseLocation polling needs no global event monitor or event tap.
extern "C" __attribute__((visibility("default"))) int WWDesktopCursor(float *x, float *y)
{
    if (!x || !y) return 0;
    __block float cx = 0, cy = 0;
    __block int valid = 0;
    void (^readCursor)(void) = ^{
        valid = [sPointer readCursorX:&cx y:&cy];
    };
    if (NSThread.isMainThread) readCursor();
    else dispatch_sync(dispatch_get_main_queue(), readCursor);
    *x = cx; *y = cy;
    return valid;
}
extern "C" __attribute__((visibility("default"))) int WWDesktopPointerUnobscured(void)
{
    __block BOOL available = NO;
    void (^check)(void) = ^{ available = [sPointer isDesktopPoint:NSEvent.mouseLocation]; };
    if (NSThread.isMainThread) check();
    else dispatch_sync(dispatch_get_main_queue(), check);
    return available ? 1 : 0;
}
extern "C" __attribute__((visibility("default"))) int WWDesktopFrameRate(void)
{
    __block int rate = 30;
    void (^readRate)(void) = ^{
        if (sSleeping || !sWindow || !sWindow.isVisible ||
            !(sWindow.occlusionState & NSWindowOcclusionStateVisible)) rate = 2;
        else if (NSProcessInfo.processInfo.lowPowerModeEnabled) rate = 15;
    };
    if (NSThread.isMainThread) readRate();
    else dispatch_sync(dispatch_get_main_queue(), readRate);
    return rate;
}
