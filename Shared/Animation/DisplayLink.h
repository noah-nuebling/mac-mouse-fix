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

/// @noGCDCleanup
///     - Delete the dead declarations and code
///     - Remove `_Unsafe` suffixes

NS_ASSUME_NONNULL_BEGIN

/// Typedefs

/// MFDisplayLinkWorkType [Sep 2026]
///     Attempt to delay events to different point in target app's 'frame cycle' to improve smoothness of scrolling in earlier 3.0.0 point releases.
///         Caused deadlocks > moved code into`Old MFDisplayLinkWorkType stuff.md` and restored the 3.0.0 version of this code.
///     Now, we don't have deadlocks anymore ([Sep 2026], after 'No more dispatch queues' refactor), so we could give it another try.
///     Alternative optimization idea:
///         [Sep 2026] On macOS 27, M4 MBA, after 'No more dispatch queues' refactor, responsiveness feels exactly the same as a trackpad, (so MFDisplayLinkWorkType delay idea may not help anymore)
///              - that is except for Safari, where we found that you need to attach an IOHIDEvent to get it to do the in-process momentum scrolling that you also get in NSScrollView and which keeps it more responsive under load.
///              -> TODO: Look into attaching the IOHIDEvent in GestureScrollSimulator.m to optimize Safari.
///                 (Opus 5.5 knows where in the WebKit source code is the implementation [Sep 2026])
///                 (Don't have time for this now because it changes the scrolling curve and stuff which Safari loads via `kMFCGEventFieldSenderID` and stuff [Sep 2026])
typedef enum {
    /// Optimize the scheduling of the DisplayLinkCallback invocations for graphics drawing. Use this if you want to draw graphics inside the DisplayLinkCallback.
    kMFDisplayLinkWorkTypeGraphicsRendering = 0,
    /// Optimize the scheduling of the DisplayLinkCallback invocations for event sending. Use this if you want to send CGEvents to other apps inside the DisplayLinkCallback.
    kMFDisplayLinkWorkTypeEventSending,
} MFDisplayLinkWorkType;

typedef struct {
    /// When the underlying CVDisplayLinkCallback() was invoked.
    ///     Note: To get `now` relative to the frame times you can use CACurrentMediaTime() I think. (Not sure if there are slight inaccuracies with this due to the whole videoTime, hostTime thing. - See comments inside DisplayLink.m for more on that.)
    ///     Plan: Maybe simplify this timing stuff to match CADisplayLink (We're not using most of this anyways [Sep 2026])
    CFTimeInterval cvCallbackTime;
    /// When the last frame was displayed
    CFTimeInterval lastFrame;
    /// When the frame after lastFrame will be displayed. (I think? - It's an estimate our code makes, the value doesn't come from the api) (Should probably rename this to `nextFrame`)
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

+ (instancetype) displayLinkOptimizedForWorkType: (MFDisplayLinkWorkType)workType runLoop: (CFRunLoopRef)runLoop name: (NSString *)name;
- (instancetype)init NS_UNAVAILABLE;

//- (void)startWithCallback:(DisplayLinkCallback)callback;
//- (void)stop;

- (void)start_UnsafeWithCallback:(DisplayLinkCallback _Nullable)callback;
- (void)stop_Unsafe;
//- (BOOL)isRunning;
- (BOOL)isRunning_Unsafe;

//- (CFTimeInterval)bestTimeBetweenFramesEstimate;
//- (CFTimeInterval)timeBetweenFrames;
//- (CFTimeInterval)nominalTimeBetweenFrames;

- (void)linkToMainScreen;
//- (void)linkToMainScreen_Unsafe;
//- (void)linkToDisplayUnderMousePointerWithEvent:(CGEventRef _Nullable)event;

@property (atomic, readonly) CFRunLoopRef runLoop;
/// ^ Expose runLoop so that Animator (which builds ontop of DisplayLink) can use it, too. Using the same thread makes sense to avoid deadlocks and stuff.

@end

NS_ASSUME_NONNULL_END
