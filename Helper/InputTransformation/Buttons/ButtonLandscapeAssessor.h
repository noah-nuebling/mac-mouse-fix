//
// --------------------------------------------------------------------------
// ButtonLandscapeAssessor.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ButtonLandscapeAssessor : NSObject
+ (void)assessMappingLandscapeWithButton:(NSNumber *)button
                                   level:(NSNumber *)level
                         activeModifiers:(NSDictionary *)activeModifiers
                                  remaps:(NSDictionary *)remaps
                          effectiveRemaps:(NSDictionary *)effectiveRemaps
                           thisClickDoBe:(BOOL *)clickActionOfThisLevelExists
                            thisDownDoBe:(BOOL *)effectForMouseDownStateOfThisLevelExists
                             greaterDoBe:(BOOL *)effectOfGreaterLevelExists;

+ (BOOL)effectExistsForButton:(NSNumber *)button remaps:(NSDictionary *)remaps effectiveRemaps:(NSDictionary *)effectiveRemaps;
+ (NSDictionary *)getEffectiveRemaps:(NSDictionary *)remaps activeModifiers:(NSDictionary *)activeModifiers;
+ (BOOL)buttonCouldStillBeUsedThisClickCycle:(NSNumber *)devID button:(NSNumber *)button level:(NSNumber *)level;

@end

NS_ASSUME_NONNULL_END
