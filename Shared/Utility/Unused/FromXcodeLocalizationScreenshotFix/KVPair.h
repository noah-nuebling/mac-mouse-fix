//
//  KVPair.h
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 12.07.24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KVPair : NSObject

@property id key;
@property id value;

+ (KVPair *)pairWithKey:(id)key value:(id)value;

@end

NS_ASSUME_NONNULL_END
