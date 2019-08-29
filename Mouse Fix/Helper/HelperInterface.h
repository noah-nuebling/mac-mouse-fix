//
//  HelperInterface.h
//  Mouse Fix
//
//  Created by Noah Nübling on 29.08.19.
//  Copyright © 2019 Noah Nuebling. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HelperInterface : NSObject
+ (NSBundle *)helperBundle;
+ (void)tellHelperToUpdateItsSettings;
+ (void)enableHelperAsUserAgent:(BOOL)enable;
+ (BOOL)helperIsActive;
@end

NS_ASSUME_NONNULL_END
