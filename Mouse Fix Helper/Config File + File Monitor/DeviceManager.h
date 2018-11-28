//
//  DeviceManager.h
//  Mouse Fix Helper
//
//  Created by Noah Nübling on 28.11.18.
//  Copyright © 2018 Noah Nuebling Enterprises Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DeviceManager : NSObject
+ (BOOL)relevantDevicesAreAttached;
+ (void)start;
@end

NS_ASSUME_NONNULL_END
