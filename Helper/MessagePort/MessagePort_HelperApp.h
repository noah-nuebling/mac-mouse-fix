//
// --------------------------------------------------------------------------
// MessagePort_HelperApp.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

@import CoreGraphics;

@interface MessagePort_HelperApp : NSObject

+ (void)load_Manual;

+ (void)sendMessageToMainApp:(NSString *)message;
@end

