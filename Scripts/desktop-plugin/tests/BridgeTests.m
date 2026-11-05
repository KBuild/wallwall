// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#include <assert.h>
#include <stdint.h>
extern int WWDesktopConfigure(void);
extern void WWDesktopRestore(void);
extern int WWDesktopIsInteractive(void);
extern int WWDesktopPointerMode(void);
extern int WWDesktopDwellMilliseconds(void);
extern int WWDesktopAmbientIntervalSeconds(void);
extern int WWDesktopAmbientCount(void);
extern int WWDesktopFrameRate(void);
extern int WWDesktopPointerUnobscured(void);
extern int WWDesktopCursor(float *, float *);
extern int WWDesktopDragState(int *, uint32_t *, uint32_t *, float *, float *, float *, float *);
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    assert(WWDesktopConfigure() == 0);
    assert(WWDesktopIsInteractive() == 0);
    assert(WWDesktopPointerMode() == 0);
    assert(WWDesktopDwellMilliseconds() == 3000);
    assert(WWDesktopAmbientIntervalSeconds() == 600);
    assert(WWDesktopAmbientCount() == 5);
    assert(WWDesktopFrameRate() == 2);
    assert(WWDesktopPointerUnobscured() == 0);
    float x = 9, y = 9;
    assert(WWDesktopCursor(NULL, &y) == 0);
    assert(WWDesktopCursor(&x, &y) == 0 && x == 0 && y == 0);
    int held = 0; uint32_t down = 0, up = 0; float px, py, rx, ry;
    assert(WWDesktopDragState(NULL, &down, &up, &px, &py, &rx, &ry) == 0);
    assert(WWDesktopDragState(&held, &down, &up, &px, &py, &rx, &ry) == 0);
    WWDesktopRestore();
    WWDesktopRestore();
    assert(WWDesktopConfigure() == 0);
    puts("All C entry points and repeated unconfigured lifecycle checks passed");
} }
