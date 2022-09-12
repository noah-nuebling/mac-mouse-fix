//
// --------------------------------------------------------------------------
// HelperServices.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HelperServices : NSObject
+ (void)enableHelperAsUserAgent:(BOOL)enable onComplete:(void (^ _Nullable)(NSError * _Nullable error))onComplete NS_SWIFT_NAME(enableHelperAsUserAgent(_:onComplete:));
+ (BOOL)helperIsActive;

+ (void)disableHelperFromHelper;
@end

NS_ASSUME_NONNULL_END
