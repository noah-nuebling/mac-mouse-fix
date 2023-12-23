//
// --------------------------------------------------------------------------
// ScrollControl.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/Foundation.h>
#import "Constants.h"

NS_ASSUME_NONNULL_BEGIN

@interface Scroll : NSObject

+ (AXUIElementRef) systemWideAXUIElement;

+ (void)load_Manual;
+ (void)startReceiving;
+ (void)stopReceiving;
+ (BOOL)isReceiving;

+ (void)resetState;
//+ (void)suspend;

+ (void)appSwitcherModificationHasBeenDeactivated;

@end

NS_ASSUME_NONNULL_END
