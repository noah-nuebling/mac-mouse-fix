//
//  ModifierInputReceiver.h
//  Mouse Fix Helper
//
//  Created by Noah Nübling on 01.07.19.
//  Copyright © 2019 Noah Nuebling Enterprises Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ModifierInputReceiver : NSObject
+ (void)initialize;
+ (void)start;
+ (void)stop;
@end

NS_ASSUME_NONNULL_END
