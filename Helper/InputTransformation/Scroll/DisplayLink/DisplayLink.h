//
// --------------------------------------------------------------------------
// DisplayLink.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^DisplayLinkBlock)(void);

@interface DisplayLink : NSObject

@property (copy) DisplayLinkBlock block;

@end

NS_ASSUME_NONNULL_END
