//
// --------------------------------------------------------------------------
// SmoothScroll.h
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Cocoa/Cocoa.h>
#import "ScrollControl.h"

@interface SmoothScroll : ScrollControl

+ (void)load_Manual;

+ (void)configureWithPxPerStep:(int)px
                     msPerStep:(int)ms
                      friction:(float)f
                 fricitonDepth:(float)fd
                  acceleration:(float)acc
          onePixelScrollsLimit:(int)opl
     fastScrollExponentialBase:(float)fs_exp
  fastScrollThreshold_inSwipes:(int)fs_thr
  scrollSwipeThreshold_inTicks:(int)sw_thr
consecutiveScrollSwipeMaxIntervall:(float)sw_int
consecutiveScrollTickMaxIntervall:(float)ti_int;

+ (void)start;
+ (void)stop;
+ (BOOL)isRunning;

+ (void)Handle_ConsecutiveScrollTickCallback:(NSTimer *)timer;
+ (void)Handle_ConsecutiveScrollSwipeCallback:(NSTimer *)timer;

@end

