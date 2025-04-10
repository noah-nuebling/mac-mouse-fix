//
// --------------------------------------------------------------------------
// MFSemaphore.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

@interface MFSemaphore : NSObject

- (instancetype _Nullable)init NS_UNAVAILABLE;
- (instancetype _Nullable)initWithUnits:(int)initialValue;
- (bool)acquireUnit:(NSDate *_Nullable)timeLimit;
- (void)releaseUnit;

@end
