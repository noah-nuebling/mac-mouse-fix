//
// --------------------------------------------------------------------------
// CaptureToasts.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CaptureToasts : NSObject
+ (void)showScrollWheelCaptureToast:(BOOL)hasBeenCaptured;
+ (void)showButtonCaptureToastWithBeforeSet:(NSSet<NSNumber *> *)beforeSet afterSet:(NSSet<NSNumber *> *)afterSet;
@end

NS_ASSUME_NONNULL_END
