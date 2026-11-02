// SPDX-License-Identifier: GPL-3.0-only
#import "WallwallPointer.h"
#import <CoreGraphics/CoreGraphics.h>

@implementation WWPointer {
    id _monitor;
    BOOL _held;
    uint32_t _downRevision, _upRevision;
    NSPoint _downPoint, _upPoint;
}
- (void)refreshMonitor
{
    if (_interactive || _mode != 1 || !_window) {
        if (_monitor) [NSEvent removeMonitor:_monitor];
        _monitor = nil;
        return;
    }
    if (_monitor) return;
    __weak WWPointer *pointer = self;
    _monitor = [NSEvent addGlobalMonitorForEventsMatchingMask:
        (NSEventMaskLeftMouseDown | NSEventMaskLeftMouseUp)
        handler:^(NSEvent *event) {
            WWPointer *owner = pointer;
            if (!owner || !owner.window) return;
            NSPoint point = NSEvent.mouseLocation;
            if (event.type == NSEventTypeLeftMouseDown) {
                owner->_held = NSPointInRect(point, owner.window.frame) &&
                    [owner isDesktopPoint:point];
                if (owner->_held) { owner->_downPoint = point; owner->_downRevision++; }
            } else if (event.type == NSEventTypeLeftMouseUp && owner->_held) {
                owner->_held = NO;
                owner->_upPoint = point;
                owner->_upRevision++;
            }
        }];
}
- (BOOL)start
{
    [self refreshMonitor];
    if (_mode != 1 || _interactive) return YES;
    return _monitor != nil;
}
- (void)setMode:(NSInteger)mode
{
    if (_mode == mode) return;
    [self resetHold];
    _mode = mode;
    [self refreshMonitor];
}
- (void)setInteractive:(BOOL)interactive
{
    if (_interactive == interactive) return;
    if (interactive) [self resetHold];
    _interactive = interactive;
    [self refreshMonitor];
}
- (void)stop
{
    if (_monitor) [NSEvent removeMonitor:_monitor];
    _monitor = nil;
    _window = nil;
    _held = NO;
}
- (void)resetHold
{
    if (!_held) return;
    _held = NO;
    _upPoint = NSEvent.mouseLocation;
    _upRevision++;
}
- (int)readDragHeld:(int *)held downRevision:(uint32_t *)downRevision upRevision:(uint32_t *)upRevision
              downX:(float *)downX downY:(float *)downY upX:(float *)upX upY:(float *)upY
{
    if (!_window || _interactive || _mode != 1 || !_monitor) return 0;
    NSRect frame = _window.frame;
    if (frame.size.width <= 0 || frame.size.height <= 0) return 0;
    *held = _held ? 1 : 0;
    *downRevision = _downRevision;
    *upRevision = _upRevision;
    *downX = (_downPoint.x - frame.origin.x) / frame.size.width;
    *downY = (_downPoint.y - frame.origin.y) / frame.size.height;
    *upX = (_upPoint.x - frame.origin.x) / frame.size.width;
    *upY = (_upPoint.y - frame.origin.y) / frame.size.height;
    return 1;
}
- (int)readCursorX:(float *)x y:(float *)y
{
    if (!_window || _interactive) return 0;
    NSRect frame = _window.frame;
    if (frame.size.width <= 0 || frame.size.height <= 0) return 0;
    NSPoint point = NSEvent.mouseLocation;
    *x = (point.x - frame.origin.x) / frame.size.width;
    *y = (point.y - frame.origin.y) / frame.size.height;
    return 1;
}

// Query at a drag press or on the throttled hover visibility check.
// Finder's desktop-icon window covers the whole desktop but its negative
// layer does not block ordinary desktop input; normal app windows do.
- (BOOL)isDesktopPoint:(NSPoint)point
{
    if (!_window || !NSPointInRect(point, _window.frame)) return NO;
    CGWindowID ownID = (CGWindowID)_window.windowNumber;
    CFArrayRef list = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenAboveWindow, ownID);
    if (!list) return NO;
    BOOL available = YES;
    CGPoint cgPoint = CGPointMake(point.x, CGDisplayBounds(CGMainDisplayID()).size.height - point.y);
    for (NSDictionary *entry in (__bridge NSArray *)list) {
        NSInteger layer = [entry[(__bridge NSString *)kCGWindowLayer] integerValue];
        if (layer < 0) continue;
        // The cursor is a Window Server window above all apps, not an input
        // blocker. Dock also publishes a transparent full-display host on Tahoe.
        if (layer == CGWindowLevelForKey(kCGCursorWindowLevelKey)) continue;
        CGFloat alpha = [entry[(__bridge NSString *)kCGWindowAlpha] doubleValue];
        if (alpha <= 0.01) continue;
        CFDictionaryRef bounds = (__bridge CFDictionaryRef)entry[(__bridge NSString *)kCGWindowBounds];
        CGRect rect = CGRectZero;
        if (bounds && CGRectMakeWithDictionaryRepresentation(bounds, &rect) &&
            layer == CGWindowLevelForKey(kCGDockWindowLevelKey)) {
            pid_t pid = [entry[(__bridge NSString *)kCGWindowOwnerPID] intValue];
            NSString *bundle = [NSRunningApplication runningApplicationWithProcessIdentifier:pid].bundleIdentifier;
            if ([bundle isEqualToString:@"com.apple.dock"]) {
                for (NSScreen *screen in NSScreen.screens) {
                    CGDirectDisplayID display = [screen.deviceDescription[@"NSScreenNumber"] unsignedIntValue];
                    if (CGRectEqualToRect(rect, CGDisplayBounds(display))) {
                        rect = CGRectZero;
                        break;
                    }
                }
                if (CGRectIsEmpty(rect)) continue;
            }
        }
        if (bounds && CGRectMakeWithDictionaryRepresentation(bounds, &rect) &&
            CGRectContainsPoint(rect, cgPoint)) { available = NO; break; }
    }
    CFRelease(list);
    return available;
}
@end
