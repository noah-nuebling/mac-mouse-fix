//
// --------------------------------------------------------------------------
// ButtonInputParser.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

@interface ButtonInputParser : NSObject

+ (void)parseInputWithButton:(int)mouseButton eventType:(int)state;


// I started implementing a more general "click gesture recognizer" which can recognize single/double/triple/... click [and hold] gestures.
/*
+ (void)parseClickGestureWithButton:(int)button state:(int)state level:(int)level holdCallback:(Boolean)hold clickCallback:(Boolean)ccb;
+ (CGEventRef)clickGestureRecognizer:(CGEventRef)event;
*/
@end

