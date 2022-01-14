//
// --------------------------------------------------------------------------
// MessagePort_App.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

@import CoreGraphics;


@interface MessagePort_App : NSObject

+ (void)load_Manual;

+ (void)sendMessageToHelper:(NSString *)message;
//+ (NSString *)sendMessageWithReplyToHelper:(NSString *)message;
@end
