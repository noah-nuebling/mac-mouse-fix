//
// --------------------------------------------------------------------------
// ButtonInputReceiver.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "IOKit/hid/IOHIDManager.h"
#import "Device.h"
#import "Constants.h"
#import "MFEventTap.h"

@interface ButtonInputReceiver : NSObject

typedef NS_ENUM(NSUInteger, MFEventPassThroughEvaluation) {
    MFEventPassThroughEvaluationApproval,
    MFEventPassThroughEvaluationRefusal,
};

typedef NS_ENUM(NSUInteger, MFButtonInputType) {
    MFButtonInputTypeButtonDown,
    MFButtonInputTypeButtonUp,
};

typedef NS_ENUM(NSInteger, MFActionTriggerType) {
    MFActionTriggerTypeNone = -1,
    MFActionTriggerTypeButtonDown = 0,
    MFActionTriggerTypeButtonUp = 1,
    MFActionTriggerTypeHoldTimerExpired = 2,
    MFActionTriggerTypeLevelTimerExpired = 3,
};

//typedef enum {
//    kMFUIActionTriggerTypeClick = 0,
//    kMFUIActionTriggerTypeHold = 1,
//    kMFUIActionTriggerTypeModifying = 2,
//} MFUIActionTriggerType;

+ (void)load_Manual;

+ (void) listenToButtons: (MFEventType)buttons;
+ (NSString *) listenedToEventsDescription;

//+ (void)insertFakeEventWithButton:(MFMouseButtonNumber)button mouseDown:(BOOL)mouseDown;

//+ (void)handleHIDButtonInputFromRelevantDeviceOccured:(Device *)dev button:(NSNumber *)btn;
//+ (BOOL)allRelevantButtonInputsHaveBeenProcessed;

@end
