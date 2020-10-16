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

+ (MFEventPassThroughEvaluation)parseInputWithButton:(int64_t)button trigger:(MFButtonInputType)type inputDevice:(MFDevice *)device;

+ (void)handleHasHadDirectEffectWithDevice:(NSNumber *)devID button:(NSNumber *)btn;
+ (void)handleHasHadEffectAsModifierWithDevice:(NSNumber *)devID button:(NSNumber *)btn;

@end

