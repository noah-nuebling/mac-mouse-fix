//
// --------------------------------------------------------------------------
// Alerts.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface Alerts : NSObject

+ (void)showStrangeHelperMessageWithStrangeURL:(NSString *)strangeURL;
+ (void)showPersistenNotificationWithTitle:(NSString *)title markdownBody:(NSString *)bodyRaw maxWidth:(int)maxWidth stayOnTop:(BOOL)isAlwaysOnTop asSheet:(BOOL)asSheet;

@end

NS_ASSUME_NONNULL_END
