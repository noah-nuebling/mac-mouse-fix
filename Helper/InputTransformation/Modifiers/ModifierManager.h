//
// --------------------------------------------------------------------------
// ModifierManager.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import "Device.h"

NS_ASSUME_NONNULL_BEGIN

@interface ModifierManager : NSObject

+ (void)load_Manual;

+ (NSDictionary *)getActiveModifiersForDevice:(Device *_Nullable *_Nullable)devicePtr filterButton:(NSNumber * _Nullable)filteredButton event:(CGEventRef _Nullable) event;

+ (NSDictionary *)getActiveModifiersForDevice:(Device *_Nullable *_Nullable)devicePtr filterButton:(NSNumber * _Nullable)filteredButton event:(CGEventRef _Nullable)event despiteAddMode:(BOOL)despiteAddMode;

+ (void)handleButtonModifiersMightHaveChangedWithDevice:(Device *)device;

+ (void)handleModifiersHaveHadEffectWithDevice:(Device *_Nullable)device;
+ (void)handleModifiersHaveHadEffectWithDevice:(Device *_Nullable)device activeModifiers:(NSDictionary *)activeModifiers;

@end

NS_ASSUME_NONNULL_END
