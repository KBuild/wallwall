// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import "WallwallDesktop-Swift.h"
#include <stdint.h>
#define WW_EXPORT __attribute__((visibility("default")))

static int32_t ReadOnMain(int32_t (^read)(void))
{
    if (NSThread.isMainThread) return read();
    __block int32_t value;
    dispatch_sync(dispatch_get_main_queue(), ^{ value = read(); });
    return value;
}
WW_EXPORT int WWDesktopConfigure(void) { return ReadOnMain(^{ return [WWDesktopHost.shared configure]; }); }
WW_EXPORT int WWDesktopIsInteractive(void) { return ReadOnMain(^{ return WWDesktopHost.shared.isInteractive; }); }
WW_EXPORT int WWDesktopPointerMode(void) { return ReadOnMain(^{ return WWDesktopHost.shared.pointerMode; }); }
WW_EXPORT int WWDesktopDwellMilliseconds(void) { return ReadOnMain(^{ return WWDesktopHost.shared.dwellMilliseconds; }); }
WW_EXPORT int WWDesktopAmbientIntervalSeconds(void) { return ReadOnMain(^{ return WWDesktopHost.shared.ambientIntervalSeconds; }); }
WW_EXPORT int WWDesktopAmbientCount(void) { return ReadOnMain(^{ return WWDesktopHost.shared.ambientCount; }); }
WW_EXPORT int WWDesktopFrameRate(void) { return ReadOnMain(^{ return WWDesktopHost.shared.frameRate; }); }
WW_EXPORT int WWDesktopPointerUnobscured(void) { return ReadOnMain(^{ return WWDesktopHost.shared.pointerUnobscured; }); }
WW_EXPORT void WWDesktopRestore(void)
{
    ReadOnMain(^{ [WWDesktopHost.shared restore]; return (int32_t)0; });
}
WW_EXPORT int WWDesktopCursor(float *x, float *y)
{
    if (!x || !y) return 0;
    return ReadOnMain(^{ return [WWDesktopHost.shared readCursorX:x y:y]; });
}
WW_EXPORT int WWDesktopDragState(int *held, uint32_t *downRevision, uint32_t *upRevision,
                               float *downX, float *downY, float *upX, float *upY)
{
    if (!held || !downRevision || !upRevision || !downX || !downY || !upX || !upY) return 0;
    return ReadOnMain(^{ return [WWDesktopHost.shared readDragHeld:held downRevision:downRevision
        upRevision:upRevision downX:downX downY:downY upX:upX upY:upY]; });
}
