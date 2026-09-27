// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>

// Owns silent MP4 wallpaper windows only on displays without the Unity window.
@interface WWFallback : NSObject
@property(nonatomic, readonly) NSUInteger windowCount;
- (void)reconcileWithUnityWindow:(NSWindow *)unityWindow sleeping:(BOOL)sleeping;
- (void)stop;
@end
