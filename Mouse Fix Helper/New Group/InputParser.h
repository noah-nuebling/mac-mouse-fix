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

NS_ASSUME_NONNULL_BEGIN

@interface InputParser : NSObject

+ (CGEventRef)parse:(int)mouseButton state:(int)state event:(CGEventRef)event;
+ (void)doSymbolicHotKeyAction: (CGSSymbolicHotKey)shk;
+ (void)handleActionArray:(NSArray *)actionArray;


+ (void)clickAndHoldCallback:(NSTimer *)timer;

// I started implementing a more general "click gesture recognizer", but I don't think that's really necessary
/*
+ (void)parseClickGestureWithButton:(int)button state:(int)state level:(int)level holdCallback:(Boolean)hold clickCallback:(Boolean)ccb;
+ (CGEventRef)clickGestureRecognizer:(CGEventRef)event;
*/
@end

NS_ASSUME_NONNULL_END
