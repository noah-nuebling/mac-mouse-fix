#import <Foundation/Foundation.h>


@interface InputParser : NSObject

+ (CGEventRef)parse:(int)mouseButton state:(int)state event:(CGEventRef)event;


// I started implementing a more general "click gesture recognizer" which can recognize single/double/triple/... click [and hold] gestures.
/*
+ (void)parseClickGestureWithButton:(int)button state:(int)state level:(int)level holdCallback:(Boolean)hold clickCallback:(Boolean)ccb;
+ (CGEventRef)clickGestureRecognizer:(CGEventRef)event;
*/
@end

