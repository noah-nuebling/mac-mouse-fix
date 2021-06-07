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

typedef void(^DisplayLinkCallback)(CVTimeStamp);

@interface DisplayLink : NSObject

@property (copy) DisplayLinkCallback callback;

+ (instancetype)displayLinkWithCallback:(DisplayLinkCallback)callback;
- (void)start;
- (void)stop;
- (CVReturn)setToMainScreen;

- (CVReturn)setToDisplayUnderMousePointerWithEvent:(CGEventRef)event;

@end

NS_ASSUME_NONNULL_END
