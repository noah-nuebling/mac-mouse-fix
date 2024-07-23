//
// --------------------------------------------------------------------------
// RemapsAnalyzer.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "Device.h"
#import "WannabePrefixHeader.h"
#import "Constants.h"

NS_ASSUME_NONNULL_BEGIN

@interface RemapsAnalyzer : NSObject

#pragma mark General

+ (void)reload;

#pragma mark For SwitchMaster

+ (BOOL)modificationsModifyButtons:(__DISABLE_SWIFT_BRIDGING(NSDictionary *))modifications maxButton:(__DISABLE_SWIFT_BRIDGING_BASE(MFMouseButtonNumber, int))maxButton NS_REFINED_FOR_SWIFT;

+ (BOOL)modificationsModifyScroll:(__DISABLE_SWIFT_BRIDGING(NSDictionary *))modifications NS_REFINED_FOR_SWIFT;
+ (BOOL)modificationsModifyPointing:(__DISABLE_SWIFT_BRIDGING(NSDictionary *))modifications NS_REFINED_FOR_SWIFT;


#pragma mark For Buttons.swift

///
/// Original declartions
///

+ (void)assessMappingLandscapeWithButton:(__DISABLE_SWIFT_BRIDGING(NSNumber *))button
                                   level:(__DISABLE_SWIFT_BRIDGING(NSNumber *))level
         modificationsActingOnThisButton:(__DISABLE_SWIFT_BRIDGING(NSDictionary *))remapsActingOnThisButton
                                  remaps:(__DISABLE_SWIFT_BRIDGING(NSDictionary *))remaps
                           thisClickDoBe:(BOOL *)clickActionOfThisLevelExists
                            thisDownDoBe:(BOOL *)effectForMouseDownStateOfThisLevelExists
                             greaterDoBe:(BOOL *)effectOfGreaterLevelExists NS_REFINED_FOR_SWIFT;

+ (BOOL)effectExistsForButton:(__DISABLE_SWIFT_BRIDGING(NSNumber *))button remaps:(__DISABLE_SWIFT_BRIDGING(NSDictionary *))remaps modificationsActingOnButton:(__DISABLE_SWIFT_BRIDGING(NSDictionary *))effectiveRemaps NS_REFINED_FOR_SWIFT;

+ (NSInteger)maxLevelForButton:(__DISABLE_SWIFT_BRIDGING(NSNumber *))button remaps:(__DISABLE_SWIFT_BRIDGING(NSDictionary *))remaps modificationsActingOnThisButton:(__DISABLE_SWIFT_BRIDGING(NSDictionary *))modificationsActingOnThisButton NS_REFINED_FOR_SWIFT;

@end

NS_ASSUME_NONNULL_END
