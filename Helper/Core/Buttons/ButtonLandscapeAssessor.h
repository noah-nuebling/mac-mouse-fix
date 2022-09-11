//
// --------------------------------------------------------------------------
// ButtonLandscapeAssessor.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "Device.h"

NS_ASSUME_NONNULL_BEGIN

@interface ButtonLandscapeAssessor : NSObject
+ (void)assessMappingLandscapeWithButton:(NSNumber *)button
                                   level:(NSNumber *)level
                modificationsActingOnThisButton:(NSDictionary *)remapsActingOnThisButton
                                  remaps:(NSDictionary *)remaps
                           thisClickDoBe:(BOOL *)clickActionOfThisLevelExists
                            thisDownDoBe:(BOOL *)effectForMouseDownStateOfThisLevelExists
                             greaterDoBe:(BOOL *)effectOfGreaterLevelExists;

+ (BOOL)effectExistsForButton:(NSNumber *)button remaps:(NSDictionary *)remaps modificationsActingOnButton:(NSDictionary *)effectiveRemaps;
//+ (BOOL)buttonCouldStillBeUsedThisClickCycle:(Device *)device button:(NSNumber *)button level:(NSNumber *)level;
+ (NSInteger)maxLevelForButton:(NSNumber *)button remaps:(NSDictionary *)remaps modificationsActingOnThisButton:(NSDictionary *)modificationsActingOnThisButton;

@end

NS_ASSUME_NONNULL_END
