//
//  Updater.h
//  Mouse Fix
//
//  Created by Noah Nübling on 21.08.19.
//  Copyright © 2019 Noah Nuebling. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Updater : NSObject//<NSURLSessionDelegate,NSURLSessionTaskDelegate>
+ (void)checkForUpdate;
+ (void)update;
@property (class,readonly) BOOL updateAvailable;
@end

NS_ASSUME_NONNULL_END
