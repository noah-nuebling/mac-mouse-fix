//
//  AppDelegate.h
//  ScrollFix Playground in OBJC weil Swift STINKT
//
//  Created by Noah Nübling on 06.11.18.
//  Copyright © 2018 Noah Nuebling Enterprises Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AnimationCurve.h"

@interface SmoothScroll : NSObject

+ (void)setHorizontalScroll: (BOOL)B;

+ (void)startWithAnimationCurve:(AnimationCurve *)curve
                      pxPerStep:(int)pxB
                         msBase:(int)msB
                          msMax:(int)msM
                       msFactor:(float)msF;
+ (void) stop;
@end

