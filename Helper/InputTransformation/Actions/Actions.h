//
// --------------------------------------------------------------------------
// Actions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "Constants.h"

NS_ASSUME_NONNULL_BEGIN

typedef enum {
    kMFActionPhaseStart,
    kMFActionPhaseEnd,
    kMFActionPhaseCombined,
} MFActionPhase;

@interface Actions : NSObject

+ (void)executeActionArray:(NSArray *)actionArray phase:(MFActionPhase)phase;

@end

NS_ASSUME_NONNULL_END
