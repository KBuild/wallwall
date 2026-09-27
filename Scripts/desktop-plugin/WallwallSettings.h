// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>

// Validated, persisted choices shared by the menu and Unity host.
@interface WWSettings : NSObject
@property(nonatomic, readonly) NSInteger pointerMode;
@property(nonatomic, readonly) NSInteger dwellMilliseconds;
@property(nonatomic, readonly) NSInteger ambientIntervalSeconds;
@property(nonatomic, readonly) NSInteger ambientCount;
- (void)setPointerMode:(NSInteger)value;
- (void)setDwellMilliseconds:(NSInteger)value;
- (void)setAmbientIntervalSeconds:(NSInteger)value;
- (void)setAmbientCount:(NSInteger)value;
@end
