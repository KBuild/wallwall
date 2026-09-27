// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#include <stdint.h>

@interface WWPointer : NSObject
@property(nonatomic, weak) NSWindow *window;
@property(nonatomic) BOOL interactive;
@property(nonatomic) NSInteger mode;
- (BOOL)start;
- (void)stop;
- (void)resetHold;
- (int)readDragHeld:(int *)held downRevision:(uint32_t *)downRevision upRevision:(uint32_t *)upRevision
              downX:(float *)downX downY:(float *)downY upX:(float *)upX upY:(float *)upY;
- (int)readCursorX:(float *)x y:(float *)y;
- (BOOL)isDesktopPoint:(NSPoint)point;
@end
