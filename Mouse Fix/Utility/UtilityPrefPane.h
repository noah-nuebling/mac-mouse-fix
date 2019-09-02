//
//  UtilityPrefPane.h
//  Mouse Fix
//
//  Created by Noah Nübling on 02.09.19.
//  Copyright © 2019 Noah Nuebling. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>


NS_ASSUME_NONNULL_BEGIN

@interface UtilityPrefPane : NSObject
+ (NSArray *)subviewsForView:(NSView *)view withIdentifier:(NSString *)identifier;
@end

NS_ASSUME_NONNULL_END
