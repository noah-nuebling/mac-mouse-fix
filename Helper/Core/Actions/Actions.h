//
// --------------------------------------------------------------------------
// Actions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "Constants.h"
#import "WannabePrefixHeader.h"
#import "CGSHotKeys.h"

NS_ASSUME_NONNULL_BEGIN

typedef enum {
    kMFActionPhaseStart,
    kMFActionPhaseEnd,
    kMFActionPhaseCombined,
} MFActionPhase;

@interface Actions : NSObject

+ (void)executeActionArray:(NSArray *)actionArray phase:(MFActionPhase)phase MF_SWIFT_HIDDEN;
+ (void)__SWIFT_UNBRIDGED_executeActionArray:(id)actionArray phase:(MFActionPhase)phase;
+ (void)postKeyboardKeyDown:(CGKeyCode)keyCode modifierFlags:(CGSModifierFlags)modifierFlags;
+ (void)postKeyboardKeyUp:(CGKeyCode)keyCode modifierFlags:(CGSModifierFlags)modifierFlags;

@end

NS_ASSUME_NONNULL_END
