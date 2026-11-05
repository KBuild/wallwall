// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#import "WallwallDesktop-Swift.h"
#include <assert.h>
int main() { @autoreleasepool {
    NSArray *ids = @[@1, @2];
    NSArray *uuids = @[@"first", @"preferred"];
    assert([[WWDisplaySelection chooseFrom:ids uuids:uuids preferred:@"preferred" fallback:@1] isEqual:@2]);
    assert([[WWDisplaySelection chooseFrom:@[@1] uuids:@[@"first"] preferred:@"preferred" fallback:@1] isEqual:@1]);
    assert(([[WWDisplaySelection chooseFrom:@[@1, @3] uuids:uuids preferred:@"preferred" fallback:@1] isEqual:@3]));
    assert([[WWDisplaySelection chooseFrom:ids uuids:uuids preferred:nil fallback:@2] isEqual:@2]);
    assert([[WWDisplaySelection chooseFrom:ids uuids:uuids preferred:nil fallback:@99] isEqual:@1]);
    assert([WWDisplaySelection chooseFrom:@[] uuids:@[] preferred:@"preferred" fallback:@1] == nil);
    WWDragState *drag = [WWDragState new];
    [drag releaseAt:NSMakePoint(3, 4)];
    assert(!drag.held && drag.upRevision == 0);
    [drag pressAt:NSMakePoint(1, 2) accepted:NO];
    assert(!drag.held && drag.downRevision == 0);
    [drag pressAt:NSMakePoint(1, 2) accepted:YES];
    [drag releaseAt:NSMakePoint(3, 4)];
    assert(!drag.held && drag.downRevision == 1 && drag.upRevision == 1);
    assert(NSEqualPoints(drag.downPoint, NSMakePoint(1, 2)));
    assert(NSEqualPoints(drag.upPoint, NSMakePoint(3, 4)));
    [drag releaseAt:NSZeroPoint];
    assert(drag.upRevision == 1);
    [drag pressAt:NSZeroPoint accepted:YES];
    [drag releaseAt:NSMakePoint(5, 6)];
    assert(drag.downRevision == 2 && drag.upRevision == 2 && !drag.held);
    assert([WWRenderPolicy frameCapWithSleeping:NO visible:YES lowPower:NO] == 30);
    assert([WWRenderPolicy frameCapWithSleeping:NO visible:YES lowPower:YES] == 15);
    assert([WWRenderPolicy frameCapWithSleeping:NO visible:NO lowPower:YES] == 2);
    assert([WWRenderPolicy frameCapWithSleeping:YES visible:YES lowPower:NO] == 2);
    assert([WWRenderPolicy shouldPlayWithSleeping:NO visible:YES]);
    assert(![WWRenderPolicy shouldPlayWithSleeping:YES visible:YES]);
    assert(![WWRenderPolicy shouldPlayWithSleeping:NO visible:NO]);
    puts("Display selection, drag transition and render policy checks passed");
} }
