//
// --------------------------------------------------------------------------
// ButtonInputParser.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "ButtonInputReceiver_CG.h"

@interface ButtonInputParser : NSObject

+ (MFEventPassThroughEvaluation)parseInputWithButton:(NSNumber *)btn trigger:(MFButtonInputType)type inputDevice:(MFDevice *)device;

+ (void)handleButtonHasHadDirectEffectWithDevice:(NSNumber *)devID button:(NSNumber *)btn;
+ (void)handleButtonHasHadEffectAsModifierWithDevice:(NSNumber *)devID button:(NSNumber *)btn;

+ (NSDictionary *)getActiveButtonModifiersForDevice:(NSNumber *)devID;

@end

