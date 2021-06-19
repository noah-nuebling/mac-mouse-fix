//
// --------------------------------------------------------------------------
// IOUtility.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface IOUtility : NSObject

+ (io_registry_entry_t)getChildOfRegistryEntry:(io_registry_entry_t)entry withName:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
