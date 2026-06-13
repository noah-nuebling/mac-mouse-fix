//
// --------------------------------------------------------------------------
// DisplayLinkTypes.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License
// --------------------------------------------------------------------------
//

#ifndef DisplayLinkTypes_h
#define DisplayLinkTypes_h

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum {
    /// Optimize the scheduling of the DisplayLinkCallback invocations for graphics drawing. Use this if you want to draw graphics inside the DisplayLinkCallback.
    kMFDisplayLinkWorkTypeGraphicsRendering = 0,
    /// Optimize the scheduling of the DisplayLinkCallback invocations for event sending. Use this if you want to send CGEvents to other apps inside the DisplayLinkCallback.
    kMFDisplayLinkWorkTypeEventSending,
} MFDisplayLinkWorkType;

typedef struct {
    /// When the underlying CVDisplayLinkCallback() was invoked.
    CFTimeInterval cvCallbackTime;
    /// When the last frame was displayed
    CFTimeInterval lastFrame;
    /// When the frame after lastFrame will be displayed.
    CFTimeInterval thisFrame;
    /// When the currently processed frame is estimated to be displayed
    CFTimeInterval outFrame;
    /// The latest device frame period reported by the displayLink
    CFTimeInterval timeBetweenFrames;
    /// The frame period target
    CFTimeInterval nominalTimeBetweenFrames;
} DisplayLinkCallbackTimeInfo;

typedef void(^DisplayLinkCallback)(DisplayLinkCallbackTimeInfo timeInfo);

NS_ASSUME_NONNULL_END

#endif /* DisplayLinkTypes_h */
