//
//  Launchd.h
//  Mouse Fix Helper
//
//  Created by Noah Nübling on 10.09.19.
//  Copyright © 2019 Noah Nuebling. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Launchd : NSObject
+ (void)enableHelperAsUserAgent:(BOOL)enable;
@end

NS_ASSUME_NONNULL_END
