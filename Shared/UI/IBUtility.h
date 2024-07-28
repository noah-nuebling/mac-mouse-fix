//
// --------------------------------------------------------------------------
// IBUtility.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "Carbon/Carbon.h"
#import "AppKit/NSEvent.h"

NS_ASSUME_NONNULL_BEGIN

@interface IBUtility : NSObject

+ (NSEventModifierFlags)modifierMaskForLiteral:(NSString *)literalString;
+ (NSString *)keyCharForLiteral:(NSString *)literalString;

@end

NS_ASSUME_NONNULL_END
