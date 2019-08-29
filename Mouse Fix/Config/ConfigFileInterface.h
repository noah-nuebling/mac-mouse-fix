//
//  ConfigFileInterface.h
//  Mouse Fix
//
//  Created by Noah Nübling on 29.08.19.
//  Copyright © 2019 Noah Nuebling. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ConfigFileInterface : NSObject
@property (class,retain) NSMutableDictionary *config;
+ (void)writeConfigToFile;
+ (void)loadConfigFromFile;
@end

NS_ASSUME_NONNULL_END
