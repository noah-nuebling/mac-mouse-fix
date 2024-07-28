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
#import "Constants.h"
#import "DisableSwiftBridging.h"

NS_ASSUME_NONNULL_BEGIN

@interface RemapsAnalyzer : NSObject

#pragma mark General

+ (void)reload;

#pragma mark For SwitchMaster

+ (BOOL)modificationsModifyButtons:(MF_SWIFT_UNBRIDGED(NSDictionary *))modifications maxButton:(MF_SWIFT_UNBRIDGED_BASE(MFMouseButtonNumber, int))maxButton NS_REFINED_FOR_SWIFT;

+ (BOOL)modificationsModifyScroll:(MF_SWIFT_UNBRIDGED(NSDictionary *))modifications NS_REFINED_FOR_SWIFT;
+ (BOOL)modificationsModifyPointing:(MF_SWIFT_UNBRIDGED(NSDictionary *))modifications NS_REFINED_FOR_SWIFT;


#pragma mark For Buttons.swift

///
/// Original declartions
///

+ (void)assessMappingLandscapeWithButton:(MF_SWIFT_UNBRIDGED(NSNumber *))button
                                   level:(MF_SWIFT_UNBRIDGED(NSNumber *))level
         modificationsActingOnThisButton:(MF_SWIFT_UNBRIDGED(NSDictionary *))remapsActingOnThisButton
                                  remaps:(MF_SWIFT_UNBRIDGED(NSDictionary *))remaps
                           thisClickDoBe:(BOOL *)clickActionOfThisLevelExists
                            thisDownDoBe:(BOOL *)effectForMouseDownStateOfThisLevelExists
                             greaterDoBe:(BOOL *)effectOfGreaterLevelExists NS_REFINED_FOR_SWIFT;

+ (BOOL)effectExistsForButton:(MF_SWIFT_UNBRIDGED(NSNumber *))button remaps:(MF_SWIFT_UNBRIDGED(NSDictionary *))remaps modificationsActingOnButton:(MF_SWIFT_UNBRIDGED(NSDictionary *))effectiveRemaps NS_REFINED_FOR_SWIFT;

+ (NSInteger)maxLevelForButton:(MF_SWIFT_UNBRIDGED(NSNumber *))button remaps:(MF_SWIFT_UNBRIDGED(NSDictionary *))remaps modificationsActingOnThisButton:(MF_SWIFT_UNBRIDGED(NSDictionary *))modificationsActingOnThisButton NS_REFINED_FOR_SWIFT;

@end

NS_ASSUME_NONNULL_END
