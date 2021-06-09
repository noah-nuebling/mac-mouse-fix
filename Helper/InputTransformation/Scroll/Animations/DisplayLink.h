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

typedef void(^DisplayLinkCallback)(void);

@interface DisplayLink : NSObject

@property (copy) DisplayLinkCallback callback;

+ (instancetype)displayLink;
- (void)startWithCallback:(DisplayLinkCallback)callback;
- (void)stop;
- (CVReturn)linkToMainScreen;

- (CVReturn)linkToDisplayUnderMousePointerWithEvent:(CGEventRef)event;

@end

NS_ASSUME_NONNULL_END
