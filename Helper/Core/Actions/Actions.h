//
// --------------------------------------------------------------------------
// Actions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "Constants.h"
#import "WannabePrefixHeader.h"

NS_ASSUME_NONNULL_BEGIN

typedef enum {
    kMFActionPhaseStart,
    kMFActionPhaseEnd,
    kMFActionPhaseCombined,
} MFActionPhase;

@interface Actions : NSObject

+ (void)executeActionArray:(NSArray *)actionArray phase:(MFActionPhase)phase MF_SWIFT_HIDDEN;
+ (void)__SWIFT_UNBRIDGED_executeActionArray:(id)actionArray phase:(MFActionPhase)phase;

@end

NS_ASSUME_NONNULL_END
