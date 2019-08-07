//
//  AppDelegate.h
//  ScrollFix Playground in OBJC weil Swift STINKT
//
//  Created by Noah Nübling on 06.11.18.
//  Copyright © 2018 Noah Nuebling Enterprises Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MomentumScroll : NSObject

typedef enum {
    kMFStandardScrollDirection      =   1,
    kMFInvertedScrollDirection      =  -1
} MFScrollDirection;

+ (void)setHorizontalScroll:(BOOL)B;
+ (void)temporarilyDisable:(BOOL)B;

+ (void)configureWithPxPerStep:(int)px
                     msPerStep:(int)ms
                      friction:(float)f
               scrollDirection:(MFScrollDirection)d;

+ (void)startOrStopDecide;

+ (BOOL)isEnabled;
+ (void)setIsEnabled: (BOOL)B;

+ (BOOL)isRunning;

@end

