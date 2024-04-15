//
// --------------------------------------------------------------------------
// DisplayLink.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// Typedefs

typedef enum {
    /// Optimize the scheduling of the DisplayLinkCallback invocations for graphics drawing. Use this if you want to draw graphics inside the DisplayLinkCallback.
    kMFDisplayLinkWorkTypeGraphicsRendering = 0,
    /// Optimize the scheduling of the DisplayLinkCallback invocations for event sending. Use this if you want to send CGEvents to other apps inside the DisplayLinkCallback.
    kMFDisplayLinkWorkTypeEventSending,
} MFDisplayLinkWorkType;

typedef struct {
    /// When the underlying CVDisplayLinkCallback() was invoked.
    ///     Note: To get `now` relative to the frame times you can use CACurrentMediaTime() I think. (Not sure if there are slight inaccuracies with this due to the whole videoTime, hostTime thing. - See comments inside DisplayLink.m for more on that.)
    CFTimeInterval cvCallbackTime;
    /// When the last frame was displayed
    CFTimeInterval lastFrame;
    /// When the frame after lastFrame will be displayed. (I think? - It's an estimate our code makes, the value doesn't come from the api)
    CFTimeInterval thisFrame;
    /// When the currently processed frame is estimated to be displayed (I think?) Seems to always be 2 frames after lastFrame from my observations. This value comes from the API and I'm not totally sure what it means.
    CFTimeInterval outFrame;
    /// The latest device frame period reported by the displayLink - In "hostTime" I think? As opposed to nominalTimeBetweenFrames which is in "videoTime"? I think?
    CFTimeInterval timeBetweenFrames;
    /// The frame period target
    CFTimeInterval nominalTimeBetweenFrames;
} DisplayLinkCallbackTimeInfo;

typedef void(^DisplayLinkCallback)(DisplayLinkCallbackTimeInfo timeInfo);

/// Class declaration

@interface DisplayLink : NSObject

@property (atomic, readwrite, copy) DisplayLinkCallback callback;
/// ^ I think setting copy on this prevented some mean bug, but I forgot the details.

+ (instancetype)displayLinkOptimizedForWorkType:(MFDisplayLinkWorkType)workType;
- (instancetype)init NS_UNAVAILABLE;

//- (void)startWithCallback:(DisplayLinkCallback)callback;
//- (void)stop;

- (void)start_UnsafeWithCallback:(DisplayLinkCallback)callback;
- (void)stop_Unsafe;
- (BOOL)isRunning;
- (BOOL)isRunning_Unsafe;

- (CFTimeInterval)bestTimeBetweenFramesEstimate;
- (CFTimeInterval)timeBetweenFrames;
- (CFTimeInterval)nominalTimeBetweenFrames;

- (void)linkToMainScreen;
- (void)linkToMainScreen_Unsafe;
- (void)linkToDisplayUnderMousePointerWithEvent:(CGEventRef _Nullable)event;

@property(atomic, readonly, strong) dispatch_queue_t dispatchQueue;
/// ^ Expose queue so that Animator (which builds ontop of DisplayLink) can use it, too. Using the same queue makes sense to avoid deadlocks and stuff

@end

NS_ASSUME_NONNULL_END
