//
//  MessagePortPref.h
//  Mouse Fix
//
//  Created by Noah Nübling on 01.09.19.
//  Copyright © 2019 Noah Nuebling. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MessagePort_PrefPane : NSObject
+ (void)sendMessageToHelper:(NSString *)message;
+ (NSString *)sendMessageWithReplyToHelper:(NSString *)message;
@end

NS_ASSUME_NONNULL_END
