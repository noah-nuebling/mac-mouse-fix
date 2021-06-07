//
// --------------------------------------------------------------------------
// MathObjc.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MathObjc : NSObject

// When in doubt, use Math.swift instead of this
// This is only used to do stuff that you can't do in Swift
// Like define a struct or enum that can be used in Swift as well as ObjC

typedef enum {
    kMFIntervalDirectionAscending,
    kMFIntervalDirectionDescending,
    kMFIntervalDirectionNone
} MFIntervalDirection;

@end

NS_ASSUME_NONNULL_END
