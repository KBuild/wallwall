// SPDX-License-Identifier: GPL-3.0-only
#import <AVFoundation/AVFoundation.h>
#import <ScreenSaver/ScreenSaver.h>

@interface WallwallSaverView : ScreenSaverView
@end

@implementation WallwallSaverView {
    AVQueuePlayer *_player;
    AVPlayerLooper *_looper;
    AVPlayerLayer *_videoLayer;
}

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        self.wantsLayer = YES;
        self.layer.backgroundColor = NSColor.blackColor.CGColor;
    }
    return self;
}

- (void)startAnimation
{
    [super startAnimation];
    if (_player) return;

    NSURL *video = [[NSBundle bundleForClass:self.class] URLForResource:@"WALLWALL" withExtension:@"mp4"];
    if (!video) {
        NSLog(@"WALLWALL screen saver: bundled MP4 unavailable");
        return;
    }

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:video options:nil];
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset];
    _player = [AVQueuePlayer queuePlayerWithItems:@[]];
    _player.muted = YES;
    _player.preventsDisplaySleepDuringVideoPlayback = NO;
    _looper = [AVPlayerLooper playerLooperWithPlayer:_player templateItem:item];
    _videoLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
    _videoLayer.frame = self.bounds;
    _videoLayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
    _videoLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.layer addSublayer:_videoLayer];
    [_player play];
}

- (void)stopAnimation
{
    [_player pause];
    [_looper disableLooping];
    [_videoLayer removeFromSuperlayer];
    _videoLayer = nil;
    _looper = nil;
    _player = nil;
    [super stopAnimation];
}

@end
