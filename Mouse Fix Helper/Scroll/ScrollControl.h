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

+ (void)load_Manual;

+ (BOOL)horizontalScrolling;
+ (void)setHorizontalScrolling:(BOOL)B;
+ (BOOL)magnificationScrolling;
+ (void)setMagnificationScrolling:(BOOL)B;

+ (CGPoint)previousMouseLocation;
+ (void)setPreviousMouseLocation:(CGPoint)p;

+ (BOOL)isSmoothEnabled;
+ (void)setIsSmoothEnabled: (BOOL)B;

+ (int)scrollDirection;

+ (void)decide;

+ (void)setConfigVariablesForActiveApp;

@end

NS_ASSUME_NONNULL_END
