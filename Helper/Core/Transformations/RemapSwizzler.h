//
// --------------------------------------------------------------------------
// RemapSwizzler.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#ifndef RemapsOverrider_h
#define RemapsOverrider_h

@import Foundation;

@interface RemapSwizzler : NSObject

+ (NSDictionary *_Nonnull)swizzleRemaps:(NSDictionary *_Nonnull)remaps activeModifiers:(NSDictionary *_Nonnull)modifiers;

@end

#endif /* RemapsOverrider_h */
