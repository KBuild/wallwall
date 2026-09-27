// SPDX-License-Identifier: GPL-3.0-only
#import "WallwallFallback.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CGWindowLevel.h>

@interface WWFallbackWindow : NSObject
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) AVQueuePlayer *player;
@property(nonatomic, strong) AVPlayerLooper *looper;
- (void)stop;
@end

@implementation WWFallbackWindow
- (void)stop
{
    [_player pause];
    [_looper disableLooping];
    [_window orderOut:nil];
    [_window close];
    _window = nil;
    _player = nil;
    _looper = nil;
}
@end

@implementation WWFallback {
    NSMutableDictionary<NSNumber *, WWFallbackWindow *> *_windows;
    NSURL *_videoURL;
    BOOL _reportedMissingVideo;
}

- (instancetype)init
{
    self = [super init];
    if (self) _windows = [NSMutableDictionary dictionary];
    return self;
}

- (NSUInteger)windowCount { return _windows.count; }

- (NSURL *)videoURL
{
    if (_videoURL) return _videoURL;
    NSString *builds = NSBundle.mainBundle.bundlePath.stringByDeletingLastPathComponent;
    NSString *path = [builds stringByAppendingPathComponent:@"WALLWALL.mp4"];
    if (![[NSFileManager defaultManager] isReadableFileAtPath:path]) {
        if (!_reportedMissingVideo) NSLog(@"WALLWALL MP4 fallback unavailable: %@", path);
        _reportedMissingVideo = YES;
        return nil;
    }
    _videoURL = [NSURL fileURLWithPath:path];
    return _videoURL;
}

- (WWFallbackWindow *)makeWindowForScreen:(NSScreen *)screen video:(NSURL *)video
{
    // A screen-specific initializer interprets this rect in that screen's
    // coordinate space and applies its origin again on external displays.
    NSWindow *window = [[NSWindow alloc] initWithContentRect:screen.frame
        styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    // ARC owns the window; close must not release it a second time.
    window.releasedWhenClosed = NO;
    window.identifier = @"WALLWALL.MP4Fallback";
    window.level = CGWindowLevelForKey(kCGDesktopIconWindowLevelKey) - 1;
    window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
        NSWindowCollectionBehaviorStationary | NSWindowCollectionBehaviorFullScreenAuxiliary;
    window.ignoresMouseEvents = YES;
    window.hidesOnDeactivate = NO;
    window.opaque = YES;
    window.backgroundColor = NSColor.blackColor;
    window.contentView.wantsLayer = YES;

    AVQueuePlayer *player = [AVQueuePlayer queuePlayerWithItems:@[]];
    player.muted = YES;
    player.preventsDisplaySleepDuringVideoPlayback = NO;
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:video];
    AVPlayerLooper *looper = [AVPlayerLooper playerLooperWithPlayer:player templateItem:item];
    AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:player];
    layer.frame = window.contentView.bounds;
    layer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
    layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [window.contentView.layer addSublayer:layer];
    [window orderFront:nil];
    [player play];

    WWFallbackWindow *result = [WWFallbackWindow new];
    result.window = window;
    result.player = player;
    result.looper = looper;
    return result;
}

- (void)reconcileWithUnityWindow:(NSWindow *)unityWindow sleeping:(BOOL)sleeping
{
    if (!unityWindow || !unityWindow.isVisible) { [self stop]; return; }
    NSScreen *unityScreen = unityWindow.screen;
    NSNumber *unityDisplay = unityScreen.deviceDescription[@"NSScreenNumber"];
    if (!unityDisplay) { [self stop]; return; }
    NSURL *video = [self videoURL];
    if (!video) { [self stop]; return; }

    NSMutableSet<NSNumber *> *wanted = [NSMutableSet set];
    for (NSScreen *screen in NSScreen.screens) {
        NSNumber *display = screen.deviceDescription[@"NSScreenNumber"];
        if (!display || [display isEqual:unityDisplay]) continue;
        [wanted addObject:display];
        WWFallbackWindow *fallback = _windows[display];
        if (!fallback) {
            fallback = [self makeWindowForScreen:screen video:video];
            _windows[display] = fallback;
            NSLog(@"WALLWALL MP4 fallback: display %@ frame %@ (video only; no interaction)",
                  display, NSStringFromRect(screen.frame));
        } else {
            if (!NSEqualRects(fallback.window.frame, screen.frame))
                [fallback.window setFrame:screen.frame display:YES];
            if (!fallback.window.isVisible) [fallback.window orderFront:nil];
        }
        if (sleeping) { if (fallback.player.rate != 0) [fallback.player pause]; }
        else if (fallback.player.rate == 0) [fallback.player play];
    }
    for (NSNumber *display in _windows.allKeys) {
        if ([wanted containsObject:display]) continue;
        [_windows[display] stop];
        [_windows removeObjectForKey:display];
        NSLog(@"WALLWALL MP4 fallback removed: display %@", display);
    }
}

- (void)stop
{
    for (WWFallbackWindow *fallback in _windows.allValues) [fallback stop];
    [_windows removeAllObjects];
}
@end
