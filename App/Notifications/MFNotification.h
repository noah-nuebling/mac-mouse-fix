//
// --------------------------------------------------------------------------
// MFNotification.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Cocoa/Cocoa.h>
#import "MFNotificationController.h"

NS_ASSUME_NONNULL_BEGIN

@interface MFNotification : NSPanel
@property MFNotificationController *controller;
@end

NS_ASSUME_NONNULL_END
