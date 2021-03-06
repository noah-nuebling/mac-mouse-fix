//
// --------------------------------------------------------------------------
// RemapUtility.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "Constants.h"

NS_ASSUME_NONNULL_BEGIN

@interface Utility_Transformation : NSObject
+ (void)hideMousePointer:(BOOL)B;
+ (void)postMouseButtonClicks:(MFMouseButtonNumber)button nOfClicks:(int64_t)nOfClicks;
+ (void)postMouseButton:(MFMouseButtonNumber)button down:(BOOL)down;
@end

NS_ASSUME_NONNULL_END
