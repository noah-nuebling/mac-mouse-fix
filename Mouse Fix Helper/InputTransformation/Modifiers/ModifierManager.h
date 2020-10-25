//
// --------------------------------------------------------------------------
// ModifierManager.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "MFDevice.h"

NS_ASSUME_NONNULL_BEGIN

@interface ModifierManager : NSObject

+ (NSDictionary *)getActiveModifiersForDevice:(NSNumber *)devID filterButton:(NSNumber * __nullable)filteredButton;

+ (void)handleButtonModifiersMightHaveChangedWithDevice:(MFDevice *)device;

+ (void)handleModifiersHaveHadEffect:(NSNumber *)devID;

@end

NS_ASSUME_NONNULL_END
