//
// --------------------------------------------------------------------------
// SmoothScroll.h
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Cocoa/Cocoa.h>

@interface SmoothScroll : NSObject

typedef enum {
    kMFStandardScrollDirection      =   1,
    kMFInvertedScrollDirection      =  -1
} MFScrollDirection;

+ (void)load_Manual;

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

+ (void)setConfigVariablesForActiveApp;


+ (void)Handle_ConsecutiveScrollTickCallback:(NSTimer *)timer;
+ (void)Handle_ConsecutiveScrollSwipeCallback:(NSTimer *)timer;

@end

