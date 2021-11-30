//
// --------------------------------------------------------------------------
// RemapsOverrider.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#ifndef RemapsOverrider_h
#define RemapsOverrider_h

@import Foundation;

@interface RemapsOverrider : NSObject

/// `MFEffectiveRemapsMethod`s are blocks that take `remaps` and `activeModifiers` as input and return `effectiveRemaps` based on those.
typedef NSDictionary *_Nonnull (^MFEffectiveRemapsMethod)(NSDictionary *_Nonnull, NSDictionary *_Nonnull);
+ (MFEffectiveRemapsMethod _Nonnull)effectiveRemapsMethod_Override;

@end

#endif /* RemapsOverrider_h */
