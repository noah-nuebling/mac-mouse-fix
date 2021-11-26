//
// --------------------------------------------------------------------------
// ScrollControl.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/Foundation.h>
#import "Constants.h"

NS_ASSUME_NONNULL_BEGIN

@interface Scroll : NSObject

+ (AXUIElementRef) systemWideAXUIElement;

+ (void)load_Manual;
+ (void)resetDynamicGlobals;
+ (void)decide;

@end

NS_ASSUME_NONNULL_END
