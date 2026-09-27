// SPDX-License-Identifier: GPL-3.0-only
#import "WallwallSettings.h"

static NSString *const PointerKey = @"WWPointerMode";
static NSString *const DwellKey = @"WWDwellMilliseconds";
static NSString *const IntervalKey = @"WWAmbientIntervalSeconds";
static NSString *const CountKey = @"WWAmbientCount";

@implementation WWSettings
- (instancetype)init
{
    if ((self = [super init])) {
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        NSInteger mode = [defaults integerForKey:PointerKey];
        _pointerMode = mode == 1 ? 1 : 0;
        NSInteger dwell = [defaults integerForKey:DwellKey];
        _dwellMilliseconds = (dwell == 1000 || dwell == 3000 || dwell == 5000 || dwell == 10000) ? dwell : 3000;
        NSInteger interval = [defaults integerForKey:IntervalKey];
        _ambientIntervalSeconds = (interval == 300 || interval == 600 || interval == 1200 || interval == 1800) ? interval : 600;
        NSInteger count = [defaults integerForKey:CountKey];
        _ambientCount = (count == 3 || count == 5 || count == 10 ||
                         (count == 0 && [defaults objectForKey:CountKey])) ? count : 5;
    }
    return self;
}
- (void)setPointerMode:(NSInteger)value
{
    if (value != 0 && value != 1) return;
    _pointerMode = value;
    [NSUserDefaults.standardUserDefaults setInteger:value forKey:PointerKey];
}
- (void)setDwellMilliseconds:(NSInteger)value
{
    if (value != 1000 && value != 3000 && value != 5000 && value != 10000) return;
    _dwellMilliseconds = value;
    [NSUserDefaults.standardUserDefaults setInteger:value forKey:DwellKey];
}
- (void)setAmbientIntervalSeconds:(NSInteger)value
{
    if (value != 300 && value != 600 && value != 1200 && value != 1800) return;
    _ambientIntervalSeconds = value;
    [NSUserDefaults.standardUserDefaults setInteger:value forKey:IntervalKey];
}
- (void)setAmbientCount:(NSInteger)value
{
    if (value != 0 && value != 3 && value != 5 && value != 10) return;
    _ambientCount = value;
    [NSUserDefaults.standardUserDefaults setInteger:value forKey:CountKey];
}
@end
