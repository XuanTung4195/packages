// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "FVPVideoPlayerPlugin.h"
#import "FVPVideoPlayerPlugin_Test.h"

#import <AVFoundation/AVFoundation.h>
#import <GLKit/GLKit.h>
#import <AVKit/AVKit.h>

#import "./include/video_player_avfoundation/AVAssetTrackUtils.h"
#import "./include/video_player_avfoundation/FVPDisplayLink.h"
#import "./include/video_player_avfoundation/messages.g.h"

#if !__has_feature(objc_arc)
#error Code Requires ARC.
#endif

@interface FVPFrameUpdater : NSObject
@property(nonatomic) int64_t textureId;
@property(nonatomic, weak, readonly) NSObject<FlutterTextureRegistry> *registry;
// The output that this updater is managing.
@property(nonatomic, weak) AVPlayerItemVideoOutput *videoOutput;
// The last time that has been validated as avaliable according to hasNewPixelBufferForItemTime:.
@property(nonatomic, assign) CMTime lastKnownAvailableTime;
@end

@interface PipManager : NSObject

@property (nonatomic, strong) FVPVideoPlayer *currentPlayer;

@property(nonatomic, strong) AVPictureInPictureController* pipController;

@property(nonatomic, strong) AVPlayerLayer* avPlayerLayer;

@property(nonatomic, weak) NSObject<FlutterPluginRegistrar> *registrar;

@property(nonatomic, strong) AVPlayer* placeHolderPlayer;

@property (nonatomic, assign) BOOL enablePlaceholderVideo;

@property (nonatomic, assign) BOOL pipEnabled;

- (void)setCurrentPlayer:(FVPVideoPlayer *)player;

- (void)onPipDidStart;

- (void)onPipDidStop;

- (void)onDisposePlayer:(FVPVideoPlayer *)player;

- (void)playBlackScreenVideo;

- (void)disposeBlackScreenVideo;

@end

@implementation FVPFrameUpdater
- (FVPFrameUpdater *)initWithRegistry:(NSObject<FlutterTextureRegistry> *)registry {
  NSAssert(self, @"super init cannot be nil");
  if (self == nil) return nil;
  _registry = registry;
  _lastKnownAvailableTime = kCMTimeInvalid;
  return self;
}

- (void)displayLinkFired {
  // Only report a new frame if one is actually available.
  CMTime outputItemTime = [self.videoOutput itemTimeForHostTime:CACurrentMediaTime()];
  if ([self.videoOutput hasNewPixelBufferForItemTime:outputItemTime]) {
    _lastKnownAvailableTime = outputItemTime;
    [_registry textureFrameAvailable:_textureId];
  }
}
@end

@interface FVPDefaultAVFactory : NSObject <FVPAVFactory>
@end

@implementation FVPDefaultAVFactory
- (AVPlayer *)playerWithPlayerItem:(AVPlayerItem *)playerItem {
  return [AVPlayer playerWithPlayerItem:playerItem];
}
- (AVPlayerItemVideoOutput *)videoOutputWithPixelBufferAttributes:
    (NSDictionary<NSString *, id> *)attributes {
  return [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:attributes];
}
@end

/// Non-test implementation of the diplay link factory.
@interface FVPDefaultDisplayLinkFactory : NSObject <FVPDisplayLinkFactory>
@end

@implementation FVPDefaultDisplayLinkFactory
- (FVPDisplayLink *)displayLinkWithRegistrar:(id<FlutterPluginRegistrar>)registrar
                                    callback:(void (^)(void))callback {
  return [[FVPDisplayLink alloc] initWithRegistrar:registrar callback:callback];
}

@end

#pragma mark -

@interface FVPVideoPlayer ()
@property(readonly, nonatomic) AVPlayerItemVideoOutput *videoOutput;
// The plugin registrar, to obtain view information from.
@property(nonatomic, weak) NSObject<FlutterPluginRegistrar> *registrar;
// The CALayer associated with the Flutter view this plugin is associated with, if any.
@property(nonatomic, readonly) CALayer *flutterViewLayer;
@property(nonatomic) FlutterEventChannel *eventChannel;
@property(nonatomic) FlutterEventSink eventSink;
@property(nonatomic) CGAffineTransform preferredTransform;
@property(nonatomic, readonly) BOOL disposed;
@property(nonatomic, readonly) BOOL isPlaying;
/// Pause the copy pixcel so the flutter texture is not updated, used when pip is enabled
@property(nonatomic, readonly) BOOL enableFrameUpdate;
@property(nonatomic) BOOL isLooping;
@property(nonatomic, readonly) BOOL isInitialized;
// The updater that drives callbacks to the engine to indicate that a new frame is ready.
@property(nonatomic) FVPFrameUpdater *frameUpdater;
// The display link that drives frameUpdater.
@property(nonatomic) FVPDisplayLink *displayLink;
// Whether a new frame needs to be provided to the engine regardless of the current play/pause state
// (e.g., after a seek while paused). If YES, the display link should continue to run until the next
// frame is successfully provided.
@property(nonatomic, assign) BOOL waitingForFrame;
@property (nonatomic, strong) id didEnterBackgroundObserver;
@property (nonatomic, strong) id willEnterForegroundObserver;

- (instancetype)initWithURL:(NSURL *)url
               frameUpdater:(FVPFrameUpdater *)frameUpdater
                displayLink:(FVPDisplayLink *)displayLink
                httpHeaders:(nonnull NSDictionary<NSString *, NSString *> *)headers
                  avFactory:(id<FVPAVFactory>)avFactory
                  registrar:(NSObject<FlutterPluginRegistrar> *)registrar;

// Tells the player to run its frame updater until it receives a frame, regardless of the
// play/pause state.
- (void)expectFrame;
@end

static void *timeRangeContext = &timeRangeContext;
static void *statusContext = &statusContext;
static void *presentationSizeContext = &presentationSizeContext;
static void *durationContext = &durationContext;
static void *playbackLikelyToKeepUpContext = &playbackLikelyToKeepUpContext;
static void *rateContext = &rateContext;

@implementation FVPVideoPlayer
- (instancetype)initWithAsset:(NSString *)asset
                 frameUpdater:(FVPFrameUpdater *)frameUpdater
                  displayLink:(FVPDisplayLink *)displayLink
                    avFactory:(id<FVPAVFactory>)avFactory
                    registrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  NSString *path = [[NSBundle mainBundle] pathForResource:asset ofType:nil];
#if TARGET_OS_OSX
  // See https://github.com/flutter/flutter/issues/135302
  // TODO(stuartmorgan): Remove this if the asset APIs are adjusted to work better for macOS.
  if (!path) {
    path = [NSURL URLWithString:asset relativeToURL:NSBundle.mainBundle.bundleURL].path;
  }
#endif
  return [self initWithURL:[NSURL fileURLWithPath:path]
              frameUpdater:frameUpdater
               displayLink:displayLink
               httpHeaders:@{}
                 avFactory:avFactory
               extraOption:nil
                 registrar:registrar];
}

- (void)dealloc {
  if (!_disposed) {
    [self removeKeyValueObservers];
  }
}

- (void)addObserversForItem:(AVPlayerItem *)item player:(AVPlayer *)player {
  [item addObserver:self
         forKeyPath:@"loadedTimeRanges"
            options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
            context:timeRangeContext];
  [item addObserver:self
         forKeyPath:@"status"
            options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
            context:statusContext];
  [item addObserver:self
         forKeyPath:@"presentationSize"
            options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
            context:presentationSizeContext];
  [item addObserver:self
         forKeyPath:@"duration"
            options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
            context:durationContext];
  [item addObserver:self
         forKeyPath:@"playbackLikelyToKeepUp"
            options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
            context:playbackLikelyToKeepUpContext];

  // Add observer to AVPlayer instead of AVPlayerItem since the AVPlayerItem does not have a "rate"
  // property
  [player addObserver:self
           forKeyPath:@"rate"
              options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
              context:rateContext];

  // Add an observer that will respond to itemDidPlayToEndTime
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(itemDidPlayToEndTime:)
                                               name:AVPlayerItemDidPlayToEndTimeNotification
                                             object:item];
}

- (void)itemDidPlayToEndTime:(NSNotification *)notification {
  if (_isLooping) {
    AVPlayerItem *p = [notification object];
    [p seekToTime:kCMTimeZero completionHandler:nil];
  } else {
    if (_eventSink) {
      _eventSink(@{@"event" : @"completed"});
    }
  }
}

const int64_t TIME_UNSET = -9223372036854775807;

NS_INLINE int64_t FVPCMTimeToMillis(CMTime time) {
  // When CMTIME_IS_INDEFINITE return a value that matches TIME_UNSET from ExoPlayer2 on Android.
  // Fixes https://github.com/flutter/flutter/issues/48670
  if (CMTIME_IS_INDEFINITE(time)) return TIME_UNSET;
  if (time.timescale == 0) return 0;
  return time.value * 1000 / time.timescale;
}

NS_INLINE CGFloat radiansToDegrees(CGFloat radians) {
  // Input range [-pi, pi] or [-180, 180]
  CGFloat degrees = GLKMathRadiansToDegrees((float)radians);
  if (degrees < 0) {
    // Convert -90 to 270 and -180 to 180
    return degrees + 360;
  }
  // Output degrees in between [0, 360]
  return degrees;
};

- (AVMutableVideoComposition *)getVideoCompositionWithTransform:(CGAffineTransform)transform
                                                      withAsset:(AVAsset *)asset
                                                 withVideoTrack:(AVAssetTrack *)videoTrack {
  AVMutableVideoCompositionInstruction *instruction =
      [AVMutableVideoCompositionInstruction videoCompositionInstruction];
  instruction.timeRange = CMTimeRangeMake(kCMTimeZero, [asset duration]);
  AVMutableVideoCompositionLayerInstruction *layerInstruction =
      [AVMutableVideoCompositionLayerInstruction
          videoCompositionLayerInstructionWithAssetTrack:videoTrack];
  [layerInstruction setTransform:_preferredTransform atTime:kCMTimeZero];

  AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
  instruction.layerInstructions = @[ layerInstruction ];
  videoComposition.instructions = @[ instruction ];

  // If in portrait mode, switch the width and height of the video
  CGFloat width = videoTrack.naturalSize.width;
  CGFloat height = videoTrack.naturalSize.height;
  NSInteger rotationDegrees =
      (NSInteger)round(radiansToDegrees(atan2(_preferredTransform.b, _preferredTransform.a)));
  if (rotationDegrees == 90 || rotationDegrees == 270) {
    width = videoTrack.naturalSize.height;
    height = videoTrack.naturalSize.width;
  }
  videoComposition.renderSize = CGSizeMake(width, height);

  // TODO(@recastrodiaz): should we use videoTrack.nominalFrameRate ?
  // Currently set at a constant 30 FPS
  videoComposition.frameDuration = CMTimeMake(1, 30);

  return videoComposition;
}

- (instancetype)initWithURL:(NSURL *)url
               frameUpdater:(FVPFrameUpdater *)frameUpdater
                displayLink:(FVPDisplayLink *)displayLink
                httpHeaders:(nonnull NSDictionary<NSString *, NSString *> *)headers
                  avFactory:(id<FVPAVFactory>)avFactory
                extraOption:(NSDictionary<NSString *, id>*)extraOption
                  registrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  NSDictionary<NSString *, id> *options = nil;
  if ([headers count] != 0) {
    options = @{@"AVURLAssetHTTPHeaderFieldsKey" : headers};
  }
  AVURLAsset *urlAsset = [AVURLAsset URLAssetWithURL:url options:options];
  AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:urlAsset];
  if (extraOption != nil) {
      id bitrate = extraOption[@"bitrate"];
      id width = extraOption[@"width"];
      id height = extraOption[@"height"];
      if ([bitrate isKindOfClass:[NSNumber class]]
          && [width isKindOfClass:[NSNumber class]]
          && [height isKindOfClass:[NSNumber class]]) {
          NSInteger _bitrate = [bitrate integerValue];
          NSInteger _width = [width integerValue];
          NSInteger _height = [height integerValue];
          item.preferredPeakBitRate = _bitrate;
          item.preferredMaximumResolution = CGSizeMake(_width, _height);
      }
  }
  return [self initWithPlayerItem:item
                     frameUpdater:frameUpdater
                      displayLink:(FVPDisplayLink *)displayLink
                        avFactory:avFactory
                        registrar:registrar];
}

- (instancetype)initWithPlayerItem:(AVPlayerItem *)item
                      frameUpdater:(FVPFrameUpdater *)frameUpdater
                       displayLink:(FVPDisplayLink *)displayLink
                         avFactory:(id<FVPAVFactory>)avFactory
                         registrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  self = [super init];
  NSAssert(self, @"super init cannot be nil");
  _enableFrameUpdate = YES;
  _registrar = registrar;
  _frameUpdater = frameUpdater;

  AVAsset *asset = [item asset];
  void (^assetCompletionHandler)(void) = ^{
    if ([asset statusOfValueForKey:@"tracks" error:nil] == AVKeyValueStatusLoaded) {
      NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
      if ([tracks count] > 0) {
        AVAssetTrack *videoTrack = tracks[0];
        void (^trackCompletionHandler)(void) = ^{
          if (self->_disposed) return;
          if ([videoTrack statusOfValueForKey:@"preferredTransform"
                                        error:nil] == AVKeyValueStatusLoaded) {
            // Rotate the video by using a videoComposition and the preferredTransform
            self->_preferredTransform = FVPGetStandardizedTransformForTrack(videoTrack);
            // Note:
            // https://developer.apple.com/documentation/avfoundation/avplayeritem/1388818-videocomposition
            // Video composition can only be used with file-based media and is not supported for
            // use with media served using HTTP Live Streaming.
            AVMutableVideoComposition *videoComposition =
                [self getVideoCompositionWithTransform:self->_preferredTransform
                                             withAsset:asset
                                        withVideoTrack:videoTrack];
            item.videoComposition = videoComposition;
          }
        };
        [videoTrack loadValuesAsynchronouslyForKeys:@[ @"preferredTransform" ]
                                  completionHandler:trackCompletionHandler];
      }
    }
  };

  _player = [avFactory playerWithPlayerItem:item];
  _player.actionAtItemEnd = AVPlayerActionAtItemEndNone;

  // This is to fix 2 bugs: 1. blank video for encrypted video streams on iOS 16
  // (https://github.com/flutter/flutter/issues/111457) and 2. swapped width and height for some
  // video streams (not just iOS 16).  (https://github.com/flutter/flutter/issues/109116). An
  // invisible AVPlayerLayer is used to overwrite the protection of pixel buffers in those streams
  // for issue #1, and restore the correct width and height for issue #2.
  _playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
  [self.flutterViewLayer addSublayer:_playerLayer];
#if TARGET_OS_IOS
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        _playerLayer.player = nil;
    }
    
    __weak typeof(self) weakSelf = self;
    self.didEnterBackgroundObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        weakSelf.playerLayer.player = nil;
    }];

    self.willEnterForegroundObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        weakSelf.playerLayer.player = weakSelf.player;
    }];
#endif
  // Configure output.
  _displayLink = displayLink;
  NSDictionary *pixBuffAttributes = @{
    (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
    (id)kCVPixelBufferIOSurfacePropertiesKey : @{}
  };
  _videoOutput = [avFactory videoOutputWithPixelBufferAttributes:pixBuffAttributes];
  frameUpdater.videoOutput = _videoOutput;

  [self addObserversForItem:item player:_player];

  [asset loadValuesAsynchronouslyForKeys:@[ @"tracks" ] completionHandler:assetCompletionHandler];

  return self;
}

- (void)setEnableFrameUpdate:(BOOL)enable {
    _enableFrameUpdate = enable;
}

- (void)observeValueForKeyPath:(NSString *)path
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
  if (context == timeRangeContext) {
    if (_eventSink != nil) {
      NSMutableArray<NSArray<NSNumber *> *> *values = [[NSMutableArray alloc] init];
      for (NSValue *rangeValue in [object loadedTimeRanges]) {
        CMTimeRange range = [rangeValue CMTimeRangeValue];
        int64_t start = FVPCMTimeToMillis(range.start);
        [values addObject:@[ @(start), @(start + FVPCMTimeToMillis(range.duration)) ]];
      }
      _eventSink(@{@"event" : @"bufferingUpdate", @"values" : values});
    }
  } else if (context == statusContext) {
    AVPlayerItem *item = (AVPlayerItem *)object;
    switch (item.status) {
      case AVPlayerItemStatusFailed:
        if (_eventSink != nil) {
          _eventSink([FlutterError
              errorWithCode:@"VideoError"
                    message:[@"Failed to load video: "
                                stringByAppendingString:[item.error localizedDescription]]
                    details:nil]);
        }
        break;
      case AVPlayerItemStatusUnknown:
        break;
      case AVPlayerItemStatusReadyToPlay:
        [item addOutput:_videoOutput];
        [self setupEventSinkIfReadyToPlay];
        [self updatePlayingState];
        break;
    }
  } else if (context == presentationSizeContext || context == durationContext) {
    AVPlayerItem *item = (AVPlayerItem *)object;
    if (item.status == AVPlayerItemStatusReadyToPlay) {
      // Due to an apparent bug, when the player item is ready, it still may not have determined
      // its presentation size or duration. When these properties are finally set, re-check if
      // all required properties and instantiate the event sink if it is not already set up.
      [self setupEventSinkIfReadyToPlay];
      [self updatePlayingState];
    }
  } else if (context == playbackLikelyToKeepUpContext) {
    [self updatePlayingState];
    if ([[_player currentItem] isPlaybackLikelyToKeepUp]) {
      if (_eventSink != nil) {
        _eventSink(@{@"event" : @"bufferingEnd"});
      }
    } else {
      if (_eventSink != nil) {
        _eventSink(@{@"event" : @"bufferingStart"});
      }
    }
  } else if (context == rateContext) {
    // Important: Make sure to cast the object to AVPlayer when observing the rate property,
    // as it is not available in AVPlayerItem.
    AVPlayer *player = (AVPlayer *)object;
    if (_eventSink != nil) {
      _eventSink(
          @{@"event" : @"isPlayingStateUpdate", @"isPlaying" : player.rate > 0 ? @YES : @NO});
    }
  }
}

- (void)updatePlayingState {
  if (!_isInitialized) {
    return;
  }
  if (_isPlaying) {
    [_player play];
  } else {
    [_player pause];
  }
  // If the texture is still waiting for an expected frame, the display link needs to keep
  // running until it arrives regardless of the play/pause state.
  _displayLink.running = _isPlaying || self.waitingForFrame;
}

- (void)setupEventSinkIfReadyToPlay {
  if (_eventSink && !_isInitialized) {
    AVPlayerItem *currentItem = self.player.currentItem;
    CGSize size = currentItem.presentationSize;
    CGFloat width = size.width;
    CGFloat height = size.height;

    // Wait until tracks are loaded to check duration or if there are any videos.
    AVAsset *asset = currentItem.asset;
    if ([asset statusOfValueForKey:@"tracks" error:nil] != AVKeyValueStatusLoaded) {
      void (^trackCompletionHandler)(void) = ^{
        if ([asset statusOfValueForKey:@"tracks" error:nil] != AVKeyValueStatusLoaded) {
          // Cancelled, or something failed.
          return;
        }
        // This completion block will run on an AVFoundation background queue.
        // Hop back to the main thread to set up event sink.
        [self performSelector:_cmd onThread:NSThread.mainThread withObject:self waitUntilDone:NO];
      };
      [asset loadValuesAsynchronouslyForKeys:@[ @"tracks" ]
                           completionHandler:trackCompletionHandler];
      return;
    }

    BOOL hasVideoTracks = [asset tracksWithMediaType:AVMediaTypeVideo].count != 0;
    BOOL hasNoTracks = asset.tracks.count == 0;

    // The player has not yet initialized when it has no size, unless it is an audio-only track.
    // HLS m3u8 video files never load any tracks, and are also not yet initialized until they have
    // a size.
    if ((hasVideoTracks || hasNoTracks) && height == CGSizeZero.height &&
        width == CGSizeZero.width) {
      return;
    }
    // The player may be initialized but still needs to determine the duration.
    int64_t duration = [self duration];
    if (duration == 0) {
      return;
    }

    _isInitialized = YES;
    _eventSink(@{
      @"event" : @"initialized",
      @"duration" : @(duration),
      @"width" : @(width),
      @"height" : @(height)
    });
  }
}

- (void)play {
  _isPlaying = YES;
  [self updatePlayingState];
}

- (void)pause {
  _isPlaying = NO;
  [self updatePlayingState];
}

- (int64_t)position {
  return FVPCMTimeToMillis([_player currentTime]);
}

- (int64_t)duration {
  // Note: https://openradar.appspot.com/radar?id=4968600712511488
  // `[AVPlayerItem duration]` can be `kCMTimeIndefinite`,
  // use `[[AVPlayerItem asset] duration]` instead.
  return FVPCMTimeToMillis([[[_player currentItem] asset] duration]);
}

- (void)seekTo:(int64_t)location completionHandler:(void (^)(BOOL))completionHandler {
  CMTime previousCMTime = _player.currentTime;
  CMTime targetCMTime = CMTimeMake(location, 1000);
  CMTimeValue duration = _player.currentItem.asset.duration.value;
  // Without adding tolerance when seeking to duration,
  // seekToTime will never complete, and this call will hang.
  // see issue https://github.com/flutter/flutter/issues/124475.
  CMTime tolerance = location == duration ? CMTimeMake(1, 1000) : kCMTimeZero;
  [_player seekToTime:targetCMTime
        toleranceBefore:tolerance
         toleranceAfter:tolerance
      completionHandler:^(BOOL completed) {
        if (CMTimeCompare(self.player.currentTime, previousCMTime) != 0) {
          // Ensure that a frame is drawn once available, even if currently paused. In theory a race
          // is possible here where the new frame has already drawn by the time this code runs, and
          // the display link stays on indefinitely, but that should be relatively harmless. This
          // must use the display link rather than just informing the engine that a new frame is
          // available because the seek completing doesn't guarantee that the pixel buffer is
          // already available.
          [self expectFrame];
        }

        if (completionHandler) {
          completionHandler(completed);
        }
      }];
}

- (void)expectFrame {
  self.waitingForFrame = YES;
  self.displayLink.running = YES;
}

- (void)setIsLooping:(BOOL)isLooping {
  _isLooping = isLooping;
}

- (void)setVolume:(double)volume {
  _player.volume = (float)((volume < 0.0) ? 0.0 : ((volume > 1.0) ? 1.0 : volume));
}

- (void)setPlaybackSpeed:(double)speed {
  // See https://developer.apple.com/library/archive/qa/qa1772/_index.html for an explanation of
  // these checks.
  if (speed > 2.0 && !_player.currentItem.canPlayFastForward) {
    if (_eventSink != nil) {
      _eventSink([FlutterError errorWithCode:@"VideoError"
                                     message:@"Video cannot be fast-forwarded beyond 2.0x"
                                     details:nil]);
    }
    return;
  }

  if (speed < 1.0 && !_player.currentItem.canPlaySlowForward) {
    if (_eventSink != nil) {
      _eventSink([FlutterError errorWithCode:@"VideoError"
                                     message:@"Video cannot be slow-forwarded"
                                     details:nil]);
    }
    return;
  }

  _player.rate = speed;
}

- (CVPixelBufferRef)copyPixelBuffer {
  CVPixelBufferRef buffer = NULL;
    if (!_enableFrameUpdate) {
        return buffer;
    }
  CMTime outputItemTime = [_videoOutput itemTimeForHostTime:CACurrentMediaTime()];
  if ([_videoOutput hasNewPixelBufferForItemTime:outputItemTime]) {
    buffer = [_videoOutput copyPixelBufferForItemTime:outputItemTime itemTimeForDisplay:NULL];
  } else {
    // If the current time isn't available yet, use the time that was checked when informing the
    // engine that a frame was available (if any).
    CMTime lastAvailableTime = self.frameUpdater.lastKnownAvailableTime;
    if (CMTIME_IS_VALID(lastAvailableTime)) {
      buffer = [_videoOutput copyPixelBufferForItemTime:lastAvailableTime itemTimeForDisplay:NULL];
    }
  }

  if (self.waitingForFrame && buffer) {
    self.waitingForFrame = NO;
    // If the display link was only running temporarily to pick up a new frame while the video was
    // paused, stop it again.
    if (!self.isPlaying) {
      self.displayLink.running = NO;
    }
  }

  return buffer;
}

- (void)onTextureUnregistered:(NSObject<FlutterTexture> *)texture {
  dispatch_async(dispatch_get_main_queue(), ^{
    [self dispose];
  });
}

- (FlutterError *_Nullable)onCancelWithArguments:(id _Nullable)arguments {
  _eventSink = nil;
  return nil;
}

- (FlutterError *_Nullable)onListenWithArguments:(id _Nullable)arguments
                                       eventSink:(nonnull FlutterEventSink)events {
  _eventSink = events;
  // TODO(@recastrodiaz): remove the line below when the race condition is resolved:
  // https://github.com/flutter/flutter/issues/21483
  // This line ensures the 'initialized' event is sent when the event
  // 'AVPlayerItemStatusReadyToPlay' fires before _eventSink is set (this function
  // onListenWithArguments is called)
  [self setupEventSinkIfReadyToPlay];
  return nil;
}

/// This method allows you to dispose without touching the event channel.  This
/// is useful for the case where the Engine is in the process of deconstruction
/// so the channel is going to die or is already dead.
- (void)disposeSansEventChannel {
  // This check prevents the crash caused by removing the KVO observers twice.
  // When performing a Hot Restart, the leftover players are disposed once directly
  // by [FVPVideoPlayerPlugin initialize:] method and then disposed again by
  // [FVPVideoPlayer onTextureUnregistered:] call leading to possible over-release.
  if (_disposed) {
    return;
  }

  _disposed = YES;
  [_playerLayer removeFromSuperlayer];
  _displayLink = nil;
  [self removeKeyValueObservers];

  [self.player replaceCurrentItemWithPlayerItem:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dispose {
    if (self.didEnterBackgroundObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.didEnterBackgroundObserver];
    }
    if (self.willEnterForegroundObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.willEnterForegroundObserver];
    }
  [self disposeSansEventChannel];
  [_eventChannel setStreamHandler:nil];
}

- (CALayer *)flutterViewLayer {
#if TARGET_OS_OSX
  return self.registrar.view.layer;
#else
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  // TODO(hellohuanlin): Provide a non-deprecated codepath. See
  // https://github.com/flutter/flutter/issues/104117
  UIViewController *root = UIApplication.sharedApplication.keyWindow.rootViewController;
#pragma clang diagnostic pop
  return root.view.layer;
#endif
}

/// Removes all key-value observers set up for the player.
///
/// This is called from dealloc, so must not use any methods on self.
- (void)removeKeyValueObservers {
  AVPlayerItem *currentItem = _player.currentItem;
  [currentItem removeObserver:self forKeyPath:@"status"];
  [currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
  [currentItem removeObserver:self forKeyPath:@"presentationSize"];
  [currentItem removeObserver:self forKeyPath:@"duration"];
  [currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
  [_player removeObserver:self forKeyPath:@"rate"];
}

@end

@interface FVPVideoPlayerPlugin () <AVPictureInPictureControllerDelegate>
@property(readonly, weak, nonatomic) NSObject<FlutterTextureRegistry> *registry;
@property(readonly, weak, nonatomic) NSObject<FlutterBinaryMessenger> *messenger;
@property(readonly, strong, nonatomic) NSObject<FlutterPluginRegistrar> *registrar;
@property(nonatomic, strong) id<FVPDisplayLinkFactory> displayLinkFactory;
@property(nonatomic, strong) id<FVPAVFactory> avFactory;
@property(nonatomic, strong) NSMutableArray* mainPlayers;
@property(nonatomic, strong) PipManager* pipManager;
@end

@implementation FVPVideoPlayerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FVPVideoPlayerPlugin *instance = [[FVPVideoPlayerPlugin alloc] initWithRegistrar:registrar];
  [registrar publish:instance];
  SetUpFVPAVFoundationVideoPlayerApi(registrar.messenger, instance);
}

- (instancetype)initWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  return [self initWithAVFactory:[[FVPDefaultAVFactory alloc] init]
              displayLinkFactory:[[FVPDefaultDisplayLinkFactory alloc] init]
                       registrar:registrar];
}

- (instancetype)initWithAVFactory:(id<FVPAVFactory>)avFactory
               displayLinkFactory:(id<FVPDisplayLinkFactory>)displayLinkFactory
                        registrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  self = [super init];
  NSAssert(self, @"super init cannot be nil");
  _registry = [registrar textures];
  _messenger = [registrar messenger];
  _registrar = registrar;
  _displayLinkFactory = displayLinkFactory ?: [[FVPDefaultDisplayLinkFactory alloc] init];
  _avFactory = avFactory ?: [[FVPDefaultAVFactory alloc] init];
  _playersByTextureId = [NSMutableDictionary dictionaryWithCapacity:1];
  _mainPlayers = [NSMutableArray array];
  return self;
}

- (void)detachFromEngineForRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  [self.playersByTextureId.allValues makeObjectsPerformSelector:@selector(disposeSansEventChannel)];
  [self.playersByTextureId removeAllObjects];
  SetUpFVPAVFoundationVideoPlayerApi(registrar.messenger, nil);
}

- (int64_t)onPlayerSetup:(FVPVideoPlayer *)player frameUpdater:(FVPFrameUpdater *)frameUpdater {
  int64_t textureId = [self.registry registerTexture:player];
  frameUpdater.textureId = textureId;
  FlutterEventChannel *eventChannel = [FlutterEventChannel
      eventChannelWithName:[NSString stringWithFormat:@"flutter.io/videoPlayer/videoEvents%lld",
                                                      textureId]
           binaryMessenger:_messenger];
  [eventChannel setStreamHandler:player];
  player.eventChannel = eventChannel;
  self.playersByTextureId[@(textureId)] = player;

  // Ensure that the first frame is drawn once available, even if the video isn't played, since
  // the engine is now expecting the texture to be populated.
  [player expectFrame];

  return textureId;
}

- (void)initialize:(FlutterError *__autoreleasing *)error {
#if TARGET_OS_IOS
  // Allow audio playback when the Ring/Silent switch is set to silent
  [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
#endif

  [self.playersByTextureId
      enumerateKeysAndObjectsUsingBlock:^(NSNumber *textureId, FVPVideoPlayer *player, BOOL *stop) {
        [self.registry unregisterTexture:textureId.unsignedIntegerValue];
        [player dispose];
      }];
  [self.playersByTextureId removeAllObjects];
}

- (nullable NSNumber *)createWithOptions:(nonnull FVPCreationOptions *)options
                                   error:(FlutterError **)error {
  FVPFrameUpdater *frameUpdater = [[FVPFrameUpdater alloc] initWithRegistry:_registry];
  FVPDisplayLink *displayLink =
      [self.displayLinkFactory displayLinkWithRegistrar:_registrar
                                               callback:^() {
                                                 [frameUpdater displayLinkFired];
                                               }];

  FVPVideoPlayer *player;
  if (options.asset) {
    NSString *assetPath;
    if (options.packageName) {
      assetPath = [_registrar lookupKeyForAsset:options.asset fromPackage:options.packageName];
    } else {
      assetPath = [_registrar lookupKeyForAsset:options.asset];
    }
    @try {
      player = [[FVPVideoPlayer alloc] initWithAsset:assetPath
                                        frameUpdater:frameUpdater
                                         displayLink:displayLink
                                           avFactory:_avFactory
                                           registrar:self.registrar];
      return @([self onPlayerSetup:player frameUpdater:frameUpdater]);
    } @catch (NSException *exception) {
      *error = [FlutterError errorWithCode:@"video_player" message:exception.reason details:nil];
      return nil;
    }
  } else if (options.uri) {
    player = [[FVPVideoPlayer alloc] initWithURL:[NSURL URLWithString:options.uri]
                                    frameUpdater:frameUpdater
                                     displayLink:displayLink
                                     httpHeaders:options.httpHeaders
                                       avFactory:_avFactory
                                     extraOption:options.extraOption
                                       registrar:self.registrar];
    [_mainPlayers addObject:player];
      /// Show in pip player
      if (_pipManager != nil && _pipManager.pipEnabled && _pipManager.pipController != nil && [_pipManager.pipController isPictureInPictureActive]) {
          player.playerLayer.player = nil;
          [_pipManager setCurrentPlayer:player];
      }
    return @([self onPlayerSetup:player frameUpdater:frameUpdater]);
  } else {
    *error = [FlutterError errorWithCode:@"video_player" message:@"not implemented" details:nil];
    return nil;
  }
}

- (void)disposePlayer:(NSInteger)textureId error:(FlutterError **)error {
  NSNumber *playerKey = @(textureId);
  FVPVideoPlayer *player = self.playersByTextureId[playerKey];
  [self.registry unregisterTexture:textureId];
  [self.playersByTextureId removeObjectForKey:playerKey];
    if (_pipManager != nil) {
        [_pipManager onDisposePlayer:player];
    }
  [_mainPlayers removeObject:player];
  if (!player.disposed) {
    [player dispose];
  }
}

- (void)setLooping:(BOOL)isLooping forPlayer:(NSInteger)textureId error:(FlutterError **)error {
  FVPVideoPlayer *player = self.playersByTextureId[@(textureId)];
  player.isLooping = isLooping;
}

- (void)setVolume:(double)volume forPlayer:(NSInteger)textureId error:(FlutterError **)error {
  FVPVideoPlayer *player = self.playersByTextureId[@(textureId)];
  [player setVolume:volume];
}

- (void)setPlaybackSpeed:(double)speed forPlayer:(NSInteger)textureId error:(FlutterError **)error {
  FVPVideoPlayer *player = self.playersByTextureId[@(textureId)];
  [player setPlaybackSpeed:speed];
}

- (void)playPlayer:(NSInteger)textureId error:(FlutterError **)error {
  FVPVideoPlayer *player = self.playersByTextureId[@(textureId)];
  [player play];
}

- (nullable NSNumber *)positionForPlayer:(NSInteger)textureId error:(FlutterError **)error {
  FVPVideoPlayer *player = self.playersByTextureId[@(textureId)];
  return @([player position]);
}

- (void)seekTo:(NSInteger)position
     forPlayer:(NSInteger)textureId
    completion:(nonnull void (^)(FlutterError *_Nullable))completion {
  FVPVideoPlayer *player = self.playersByTextureId[@(textureId)];
  [player seekTo:position
      completionHandler:^(BOOL finished) {
        dispatch_async(dispatch_get_main_queue(), ^{
          completion(nil);
        });
      }];
}

- (void)pausePlayer:(NSInteger)textureId error:(FlutterError **)error {
  FVPVideoPlayer *player = self.playersByTextureId[@(textureId)];
  [player pause];
}

- (NSNumber *)enablePictureInPicture:(NSString *)command data:(NSDictionary<NSString *, id> *)data error:(FlutterError **)error {
    NSLog(@"enablePictureInPicture command: %@", command);
    if (![AVPictureInPictureController isPictureInPictureSupported]) {
        NSLog(@"PictureInPicture IS NOT Supported");
        return @0;
    }
    // [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback error:nil];
    // [[AVAudioSession sharedInstance] setActive:YES error:nil];
    
    UIWindow *rootWindow = nil;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow) {
            rootWindow = window;
            break;
        }
    }
    
    if (rootWindow == nil) {
        return @0;
    }
    
    if (_pipManager == nil) {
        _pipManager = [[PipManager alloc] init];
        _pipManager.enablePlaceholderVideo = YES;
        _pipManager.registrar = _registrar;
        AVPlayerLayer* avPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:nil];
        avPlayerLayer.hidden = YES;
        _pipManager.avPlayerLayer = avPlayerLayer;
        AVPictureInPictureController* pipController = [[AVPictureInPictureController alloc] initWithPlayerLayer:avPlayerLayer];
        pipController.delegate = self;
        _pipManager.pipController = pipController;
        _pipManager.pipEnabled = NO;
    }
    
    if (_pipManager.avPlayerLayer.superlayer != rootWindow.rootViewController.view.layer) {
        [_pipManager.avPlayerLayer removeFromSuperlayer];
        [rootWindow.rootViewController.view.layer addSublayer:_pipManager.avPlayerLayer];
    }
    
    if ([command isEqualToString:@"disable"]) {
        if (_pipManager != nil && _pipManager.pipController != nil) {
            [_pipManager onPipDidStop];
            [_pipManager.pipController stopPictureInPicture];
        }
    } else if ([command isEqualToString:@"enable"]) {
        CGFloat x = 0;
        CGFloat y = 30;
        CGFloat width = [UIScreen mainScreen].bounds.size.width;
        CGFloat height = width * 9 / 16;
        
        NSNumber *top = data[@"top"];
        NSNumber *left = data[@"left"];
        NSNumber *mWidth = data[@"width"];
        NSNumber *mHeight = data[@"height"];
        if (left != nil) {
            x = [left doubleValue];
        }
        if (top != nil) {
            y = [top doubleValue];
        }
        if (mWidth != nil) {
            width = [mWidth doubleValue];
        }
        if (mHeight != nil) {
            height = [mHeight doubleValue];
        }
        _pipManager.avPlayerLayer.frame = CGRectMake(x, y, width, height);
        
        if (_mainPlayers.count > 0) {
            FVPVideoPlayer *player = _mainPlayers.lastObject;
            player.playerLayer.player = nil;
            // player.player.allowsExternalPlayback = YES;
            // player.player.accessibilityElementsHidden = YES;
            [_pipManager setCurrentPlayer:player];
        } else {
            /// TODO: blank player
            _pipManager.avPlayerLayer.player = nil;
        }

        //    if (@available(iOS 14.2, *)) {
        //        _pipController.canStartPictureInPictureAutomaticallyFromInline = YES;
        //    }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSLog(@"pipController startPictureInPicture");
            [self.pipManager.pipController startPictureInPicture];
        });
        return @1;
    } else if ([command isEqualToString:@"enablePlaceholderVideo"]) {
        _pipManager.enablePlaceholderVideo = YES;
    } else if ([command isEqualToString:@"disablePlaceholderVideo"]) {
        _pipManager.enablePlaceholderVideo = NO;
    }
    else if ([command isEqualToString:@"playBlackScreenVideo"]) {
        [_pipManager playBlackScreenVideo];
    } else if ([command isEqualToString:@"disposeBlackScreenVideo"]) {
        [_pipManager disposeBlackScreenVideo];
    }

    return @1;
}

/// Start PIP listener AVPictureInPictureControllerDelegate
- (void)pictureInPictureControllerWillStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    NSLog(@"pictureInPictureControllerWillStartPictureInPicture");
    _pipManager.pipEnabled = YES;
}

- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    NSLog(@"pictureInPictureControllerDidStartPictureInPicture");
    _pipManager.pipEnabled = YES;
    [_pipManager onPipDidStart];
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController failedToStartPictureInPictureWithError:(NSError *)error {
    NSLog(@"failedToStartPictureInPictureWithError %@", error.localizedDescription);
    _pipManager.pipEnabled = NO;
    [_pipManager onPipDidStop];
}

- (void)pictureInPictureControllerWillStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    NSLog(@"pictureInPictureControllerWillStopPictureInPicture");
    _pipManager.pipEnabled = NO;
}

- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    NSLog(@"pictureInPictureControllerDidStopPictureInPicture");
    _pipManager.pipEnabled = NO;
    [_pipManager onPipDidStop];
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler {
    NSLog(@"restoreUserInterfaceForPictureInPictureStopWithCompletionHandler");
}

/// End AVPictureInPictureControllerDelegate listener

- (void)setMixWithOthers:(BOOL)mixWithOthers
                   error:(FlutterError *_Nullable __autoreleasing *)error {
#if TARGET_OS_OSX
  // AVAudioSession doesn't exist on macOS, and audio always mixes, so just no-op.
#else
  if (mixWithOthers) {
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback
                                     withOptions:AVAudioSessionCategoryOptionMixWithOthers
                                           error:nil];
  } else {
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
  }
#endif
}

@end


@implementation PipManager

- (void)setCurrentPlayer:(FVPVideoPlayer *)player {
    if (_currentPlayer != nil && _currentPlayer != player) {
        [_currentPlayer setEnableFrameUpdate:YES];
        _currentPlayer = nil;
    }
    _currentPlayer = player;
    if (self.avPlayerLayer != nil) {
        if (player != nil) {
            self.avPlayerLayer.player = player.player;
        } else {
            if (_enablePlaceholderVideo) {
                [self playBlackScreenVideo];
            } else {
                self.avPlayerLayer.player = nil;
            }
        }
    }
}

- (void)onPipDidStart {
    if (_currentPlayer != nil) {
        [_currentPlayer setEnableFrameUpdate:NO];
    }
}

- (void)onPipDidStop {
    if (_currentPlayer != nil) {
        [self setCurrentPlayer:nil];
    }
    if (_avPlayerLayer != nil) {
        [_avPlayerLayer removeFromSuperlayer];
    }
    [self disposeBlackScreenVideo];
}

- (void)onDisposePlayer:(FVPVideoPlayer *)player {
    if (_currentPlayer == player) {
        _currentPlayer = nil;
        if (self.avPlayerLayer != nil && self.avPlayerLayer.player == player.player) {
            if (!_enablePlaceholderVideo) {
                self.avPlayerLayer.player = nil;
            }
        }
    }
    if (_enablePlaceholderVideo) {
        [self playBlackScreenVideo];
    }
}

- (void)playBlackScreenVideo {
    NSString *assetPath;
    assetPath = [_registrar lookupKeyForAsset:@"assets/mp4/pip_black.mp4"];
    NSString *bundlePath = [[NSBundle mainBundle] pathForResource:assetPath ofType:nil];
    if (bundlePath != nil && _avPlayerLayer != nil && _pipController != nil) {
        if (_placeHolderPlayer != nil) {
            [_placeHolderPlayer pause];
            // [_placeHolderPlayer replaceCurrentItemWithPlayerItem:nil];
            _placeHolderPlayer = nil;
        }
        AVURLAsset *asset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:bundlePath]];
        AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:asset];
        _placeHolderPlayer = [AVPlayer playerWithPlayerItem:playerItem];
        _placeHolderPlayer.muted = YES;
        _placeHolderPlayer.allowsExternalPlayback = YES;
        _placeHolderPlayer.accessibilityElementsHidden = YES;
        [_placeHolderPlayer play];
        self.avPlayerLayer.player = _placeHolderPlayer;
        if (_currentPlayer != nil) {
            [_currentPlayer setEnableFrameUpdate:YES];
            _currentPlayer = nil;
        }
    }
}

- (void)disposeBlackScreenVideo {
    if (_placeHolderPlayer != nil) {
        if (_avPlayerLayer.player == _placeHolderPlayer) {
            _avPlayerLayer.player = nil;
        }
        [_placeHolderPlayer pause];
        [_placeHolderPlayer replaceCurrentItemWithPlayerItem:nil];
        _placeHolderPlayer = nil;
    }
}

@end
