//
//  UtilityPrefPane.m
//  Mouse Fix
//
//  Created by Noah Nübling on 02.09.19.
//  Copyright © 2019 Noah Nuebling. All rights reserved.
//

#import "UtilityPrefPane.h"
#import <AppKit/AppKit.h>

@implementation UtilityPrefPane
+ (NSArray *)subviewsForView:(NSView *)view withIdentifier:(NSString *)identifier {
    NSMutableArray *subviews = [[NSMutableArray alloc] init];
    for (NSView *v in view.subviews) {
        if ([v.identifier isEqualToString:identifier]) {
            [subviews addObject:v];
        }
    }
    return subviews;
}
@end
