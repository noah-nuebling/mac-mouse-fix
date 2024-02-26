//
// --------------------------------------------------------------------------
// EventUtility.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
//#import "MFHIDEventImports.h"

NS_ASSUME_NONNULL_BEGIN

@interface EventUtility : NSObject

int64_t fixedScrollDelta(double scrollDelta);
IOHIDDeviceRef _Nullable CGEventGetSendingDevice(CGEventRef cgEvent);
uint64_t CGEventGetSenderID(CGEventRef cgEvent);
//IOHIDDeviceRef _Nullable HIDEventGetSendingDevice(HIDEvent *event);
IOHIDDeviceRef _Nullable getSendingDeviceWithSenderID(uint64_t senderID);
CFTimeInterval CGEventGetTimestampInSeconds(CGEventRef event);
//CFTimeInterval machDeltaToTimeInterval(uint64_t machTime1, uint64_t machTime2);
NSString *scrollEventDescription(CGEventRef scrollEvent);
NSString *scrollEventDescriptionWithOptions(CGEventRef scrollEvent, BOOL allDeltas, BOOL phases);

@end

NS_ASSUME_NONNULL_END
