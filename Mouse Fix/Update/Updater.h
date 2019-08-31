//
//  Updater.h
//  Mouse Fix
//
//  Created by Noah Nübling on 21.08.19.
//  Copyright © 2019 Noah Nuebling. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Updater : NSObject

/**
 Entry point for this class.
 No class except UpdateWindow should ever interact with Updater through any other method.
 */
+ (void)checkForUpdate;

/**
 Only UpdateWindow should call this method - after it received the according user input.
 */
+ (void)skipAvailableVersion;
/**
 Only UpdateWindow should call this method - after it received the according user input.
 */
+ (void)update;
@end

NS_ASSUME_NONNULL_END
