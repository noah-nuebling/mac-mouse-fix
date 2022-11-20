//
// --------------------------------------------------------------------------
// Modifiers.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import "Device.h"

NS_ASSUME_NONNULL_BEGIN

@interface Modifiers : NSObject

+ (void)load_Manual;

+ (NSDictionary *)getActiveModifiersForDevice:(Device *)device event:(CGEventRef _Nullable) event;

+ (void)handleButtonModifiersMightHaveChangedWithDevice:(Device *)device;

+ (void)handleModificationHasBeenUsedWithDevice:(Device *_Nullable)device;
+ (void)handleModificationHasBeenUsedWithDevice:(Device *_Nullable)device activeModifiers:(NSDictionary *)activeModifiers;

@end

NS_ASSUME_NONNULL_END
