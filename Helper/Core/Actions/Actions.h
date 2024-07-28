//
// --------------------------------------------------------------------------
// Actions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "Constants.h"
#import "DisableSwiftBridging.h"

NS_ASSUME_NONNULL_BEGIN

typedef enum {
    kMFActionPhaseStart,
    kMFActionPhaseEnd,
    kMFActionPhaseCombined,
} MFActionPhase;

@interface Actions : NSObject

+ (void)executeActionArray:(MF_SWIFT_UNBRIDGED(NSArray *))actionArray phase:(MFActionPhase)phase NS_REFINED_FOR_SWIFT;

@end

NS_ASSUME_NONNULL_END
