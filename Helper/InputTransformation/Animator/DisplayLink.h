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
    CFTimeInterval now; /// When displayLinkCallback() is called
    CFTimeInterval lastFrame; /// When the last frame was displayed
    CFTimeInterval outFrame; /// When the currently processed frame will be displayed
    CFTimeInterval timeBetweenFrames; /// The latest frame period reported by the displayLink
    CFTimeInterval nominalTimeBetweenFrames; /// The frame period target
} DisplayLinkCallbackTimeInfo;

typedef void(^DisplayLinkCallback)(DisplayLinkCallbackTimeInfo timeInfo);

/// Class declaration

@interface DisplayLink : NSObject

@property (atomic, readwrite, copy) DisplayLinkCallback callback;
/// ^ I think setting copy on this prevented some mean bug, but I forgot the details.

+ (instancetype)displayLink;
- (void)startWithCallback:(DisplayLinkCallback)callback;
- (void)stop;
- (BOOL)isRunning;
- (CFTimeInterval)timeBetweenFrames;
- (CFTimeInterval)nominalTimeBetweenFrames;
- (void)linkToMainScreen;

- (void)linkToDisplayUnderMousePointerWithEvent:(CGEventRef)event;

@end

NS_ASSUME_NONNULL_END
