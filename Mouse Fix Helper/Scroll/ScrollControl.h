//
// --------------------------------------------------------------------------
// ScrollControl.h
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ScrollControl : NSObject

typedef enum {
    kMFStandardScrollDirection      =   1,
    kMFInvertedScrollDirection      =  -1
} MFScrollDirection;

+ (CGEventSourceRef)eventSource;
+ (BOOL)horizontalScrolling;
+ (void)setHorizontalScrolling:(BOOL)B;
+ (BOOL)magnificationScrolling;
+ (void)setMagnificationScrolling:(BOOL)B;
+ (CGPoint)previousMouseLocation;
+ (void)setPreviousMouseLocation:(CGPoint)p;
+ (BOOL)isSmoothEnabled;
+ (void)setIsSmoothEnabled: (BOOL)B;
+ (int)scrollDirection;
+ (void)setScrollDirection:(int)dir;

+ (void)load_Manual;
+ (void)resetDynamicGlobals;
+ (void)decide;

@end

NS_ASSUME_NONNULL_END
