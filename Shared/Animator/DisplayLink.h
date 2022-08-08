//
// --------------------------------------------------------------------------
// DisplayLink.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// Typedefs

typedef struct {
    /// When displayLinkCallback() is called
    CFTimeInterval now;
    /// When the last frame was displayed
    CFTimeInterval lastFrame;
    /// When the currently processed frame will be displayed
    CFTimeInterval outFrame;
    /// The latest frame period reported by the displayLink
    CFTimeInterval timeBetweenFrames;
    /// The frame period target
    CFTimeInterval nominalTimeBetweenFrames;
} DisplayLinkCallbackTimeInfo;

typedef void(^DisplayLinkCallback)(DisplayLinkCallbackTimeInfo timeInfo);

/// Class declaration

@interface DisplayLink : NSObject

@property (atomic, readwrite, copy) DisplayLinkCallback callback;
/// ^ I think setting copy on this prevented some mean bug, but I forgot the details.

+ (instancetype)displayLink;

//- (void)startWithCallback:(DisplayLinkCallback)callback;
//- (void)stop;

- (void)start_UnsafeWithCallback:(DisplayLinkCallback)callback;
- (void)stop_Unsafe;
- (BOOL)isRunning;
- (BOOL)isRunning_Unsafe;

- (CFTimeInterval)timeBetweenFrames;
- (CFTimeInterval)nominalTimeBetweenFrames;
- (void)linkToMainScreen;
- (void)linkToMainScreen_Unsafe;

- (void)linkToDisplayUnderMousePointerWithEvent:(CGEventRef)event;

@property(atomic, readonly, strong) dispatch_queue_t dispatchQueue;
/// ^ Expose queue so that Animator (which builds ontop of DisplayLink) can use it, too. Using the same queue makes sense to avoid deadlocks and stuff

@end

NS_ASSUME_NONNULL_END
