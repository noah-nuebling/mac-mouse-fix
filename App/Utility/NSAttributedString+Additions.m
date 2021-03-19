//
// --------------------------------------------------------------------------
// NSAttributedString+Additions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "NSAttributedString+Additions.h"
#import <Cocoa/Cocoa.h>

@implementation NSAttributedString (Additions)

- (NSAttributedString *)stringByAddingLinkWithURL:(NSString*)linkURL forSubstring:(NSString*)substring {
    
    NSMutableAttributedString *str = self.mutableCopy;
    
     NSRange foundRange = [str.mutableString rangeOfString:substring];
     if (foundRange.location != NSNotFound) {
         [str addAttribute:NSLinkAttributeName value:linkURL range:foundRange];
     }
     return str;
}
@end
