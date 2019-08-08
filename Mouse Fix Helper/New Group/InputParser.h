//
//  InputParser.h
//  Mouse Remap Helper
//
//  Created by Noah Nübling on 19.11.18.
//  Copyright © 2018 Noah Nuebling Enterprises Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CGSInternal/CGSHotKeys.h"
#import "SensibleSideButtons/TouchEvents.h"


@interface InputParser : NSObject

+ (CGEventRef)parse:(int)mouseButton state:(int)state event:(CGEventRef)event;


// I started implementing a more general "click gesture recognizer" which can recognize single/double/triple/... click [and hold] gestures.
/*
+ (void)parseClickGestureWithButton:(int)button state:(int)state level:(int)level holdCallback:(Boolean)hold clickCallback:(Boolean)ccb;
+ (CGEventRef)clickGestureRecognizer:(CGEventRef)event;
*/
@end

