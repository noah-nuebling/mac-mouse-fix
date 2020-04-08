//
// --------------------------------------------------------------------------
// Hyperlink.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Cocoa/Cocoa.h>


@interface Hyperlink : NSTextField
@property (nonatomic) IBInspectable NSString *href;
@property (nonatomic) IBInspectable int linkFrom;
@property (nonatomic) IBInspectable int linkTo;
@end
