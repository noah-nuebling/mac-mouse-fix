//
// --------------------------------------------------------------------------
// ButtonInputParser.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "ButtonInputReceiver.h"

@interface ButtonTriggerGenerator : NSObject

+ (MFEventPassThroughEvaluation)parseInputWithButton:(NSNumber *)btn triggerType:(MFButtonInputType)type inputDevice:(Device *)device;

+ (void)handleButtonHasHadDirectEffectWithDevice:(NSNumber *)devID button:(NSNumber *)btn;
+ (void)handleButtonHasHadEffectAsModifierWithDevice:(NSNumber *)devID button:(NSNumber *)btn;

+ (NSArray *)getActiveButtonModifiersForDevice:(NSNumber *_Nullable *_Nonnull)devIDPtr;

@end

