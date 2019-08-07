//
//  Hyperlink.h
//  Mouse Fix
//
//  Created by Noah Nübling on 05.08.19.
//  Copyright © 2019 Noah Nuebling Enterprises Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface Hyperlink : NSTextField
@property (nonatomic) IBInspectable NSString *href;
@property (nonatomic) IBInspectable int linkFrom;
@property (nonatomic) IBInspectable int linkTo;
@end

NS_ASSUME_NONNULL_END
