//
// --------------------------------------------------------------------------
// MessagePort_HelperApp.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

@interface MessagePort_HelperApp : NSObject

+ (void)load_Manual;

+ (void)sendMessageToPrefPane:(NSString *)message;
@end

