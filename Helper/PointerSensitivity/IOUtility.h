//
// --------------------------------------------------------------------------
// IOUtility.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <IOKit/hidsystem/IOHIDServiceClient.h>

NS_ASSUME_NONNULL_BEGIN

@interface IOUtility : NSObject

+ (void)iterateParentsOfEntry:(io_registry_entry_t)entry forEach:(Boolean (^)(io_registry_entry_t))workload;
+ (io_registry_entry_t)createChildOfRegistryEntry:(io_registry_entry_t)entry withName:(NSString *)name;
+ (void)afterDelay:(double)delay runBlock:(void(^)(void))block;
+ (NSString *)registryPathForServiceClient:(IOHIDServiceClientRef)service;
@end

NS_ASSUME_NONNULL_END
