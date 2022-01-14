//
// --------------------------------------------------------------------------
// ScrollControl.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

@import CoreGraphics;
@import ApplicationServices;
@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface ScrollControl : NSObject

typedef enum {
    kMFStandardScrollDirection      =   1,
    kMFInvertedScrollDirection      =  -1
} MFScrollDirection;

+ (AXUIElementRef) systemWideAXUIElement;
+ (CGEventSourceRef)eventSource;

+ (void)configureWithParameters:(NSDictionary *)params;

+ (double)fastScrollExponentialBase;
+ (double)fastScrollFactor;
+ (int)scrollSwipeThreshold_inTicks;
+ (double)fastScrollThreshold_inSwipes;
+ (double)consecutiveScrollTickMaxIntervall;
+ (double)consecutiveScrollSwipeMaxIntervall;

+ (BOOL)isSmoothEnabled;
+ (void)setIsSmoothEnabled: (BOOL)B;
+ (int)scrollDirection;
+ (void)setScrollDirection:(int)dir;

+ (void)load_Manual;
+ (void)resetDynamicGlobals;
+ (void)decide;

+ (void)rerouteScrollEventToTop:(CGEventRef)event;

@end

NS_ASSUME_NONNULL_END
