//
// --------------------------------------------------------------------------
// CaptureNotifications.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CaptureNotificationCreator : NSObject
+ (void)showButtonCaptureNotificationWithBeforeSet:(NSSet<NSNumber *> *)beforeSet afterSet:(NSSet<NSNumber *> *)afterSet;
@end

NS_ASSUME_NONNULL_END
