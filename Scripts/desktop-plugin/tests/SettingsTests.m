// SPDX-License-Identifier: GPL-3.0-only
#import "WallwallDesktop-Swift.h"
#include <assert.h>
int main() { @autoreleasepool {
    NSString *suite = [@"app.wallwall.tests." stringByAppendingString:NSUUID.UUID.UUIDString];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
    @try {
        WWSettings *s = [[WWSettings alloc] initWithDefaults:defaults];
        assert(s.pointerMode == 0 && s.dwellMilliseconds == 3000);
        assert(s.ambientIntervalSeconds == 600 && s.ambientCount == 5);
        [s setPointerMode:1]; [s setDwellMilliseconds:10000];
        [s setAmbientIntervalSeconds:1800]; [s setAmbientCount:0];
        s = [[WWSettings alloc] initWithDefaults:defaults];
        assert(s.pointerMode == 1 && s.dwellMilliseconds == 10000);
        assert(s.ambientIntervalSeconds == 1800 && s.ambientCount == 0);
        [s setPointerMode:-1]; [s setDwellMilliseconds:42];
        [s setAmbientIntervalSeconds:0]; [s setAmbientCount:99];
        s = [[WWSettings alloc] initWithDefaults:defaults];
        assert(s.pointerMode == 1 && s.dwellMilliseconds == 10000);
        assert(s.ambientIntervalSeconds == 1800 && s.ambientCount == 0);
        for (NSString *key in @[@"WWPointerMode", @"WWDwellMilliseconds", @"WWAmbientIntervalSeconds", @"WWAmbientCount"])
            [defaults setInteger:-99 forKey:key];
        s = [[WWSettings alloc] initWithDefaults:defaults];
        assert(s.pointerMode == 0 && s.dwellMilliseconds == 3000);
        assert(s.ambientIntervalSeconds == 600 && s.ambientCount == 5);
        for (NSNumber *value in @[@0, @1]) {
            [s setPointerMode:value.integerValue];
            assert([[WWSettings alloc] initWithDefaults:defaults].pointerMode == value.integerValue);
        }
        for (NSNumber *value in @[@1000, @3000, @5000, @10000]) {
            [s setDwellMilliseconds:value.integerValue];
            assert([[WWSettings alloc] initWithDefaults:defaults].dwellMilliseconds == value.integerValue);
        }
        for (NSNumber *value in @[@300, @600, @1200, @1800]) {
            [s setAmbientIntervalSeconds:value.integerValue];
            assert([[WWSettings alloc] initWithDefaults:defaults].ambientIntervalSeconds == value.integerValue);
        }
        for (NSNumber *value in @[@0, @3, @5, @10]) {
            [s setAmbientCount:value.integerValue];
            assert([[WWSettings alloc] initWithDefaults:defaults].ambientCount == value.integerValue);
        }
        puts("Settings regression checks passed");
    } @finally { [defaults removePersistentDomainForName:suite]; }
} }
