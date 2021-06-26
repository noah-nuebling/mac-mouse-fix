//
// --------------------------------------------------------------------------
// SmoothScroll.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Cocoa/Cocoa.h>
#import "Scroll.h"
#import "ScrollAnalyzer.h"

@interface SmoothScroll : Scroll

+ (void)load_Manual;

+ (void)start;
+ (void)stop;
+ (BOOL)hasStarted;
+ (BOOL)isScrolling;

+ (void)handleInput:(CGEventRef)event scrollAnalysisResult:(ScrollAnalysisResult)scrollAnalysisResult;

@end

