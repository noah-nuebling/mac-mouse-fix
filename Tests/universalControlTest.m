//
// --------------------------------------------------------------------------
// universalControlTest.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#define range(i, n) (int i = 0; i < (n); i++)
#define mflog(x...) os_log(OS_LOG_DEFAULT, x)
#define stringf(x...) [NSString stringWithFormat: x]

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGEvent.h>
#import <OSLog/OSLog.h>

static CFMachPortRef _eventTap = NULL;

/// Idea: Maybe put these `Description` functions in some reusable header for the main MMF project

NSString *CGEventType_Description(CGEventType type) {
    switch (type) {
        case /*0*/NX_NULLEVENT:          return @"NULLEVENT";
        case /*1*/NX_LMOUSEDOWN:         return @"LMOUSEDOWN";
        case /*2*/NX_LMOUSEUP:           return @"LMOUSEUP";
        case /*3*/NX_RMOUSEDOWN:         return @"RMOUSEDOWN";
        case /*4*/NX_RMOUSEUP:           return @"RMOUSEUP";
        case /*5*/NX_MOUSEMOVED:         return @"MOUSEMOVED";
        case /*6*/NX_LMOUSEDRAGGED:      return @"LMOUSEDRAGGED";
        case /*7*/NX_RMOUSEDRAGGED:      return @"RMOUSEDRAGGED";
        case /*8*/NX_MOUSEENTERED:       return @"MOUSEENTERED";
        case /*9*/NX_MOUSEEXITED:        return @"MOUSEEXITED";
        case /*25*/NX_OMOUSEDOWN:        return @"OMOUSEDOWN";
        case /*26*/NX_OMOUSEUP:          return @"OMOUSEUP";
        case /*27*/NX_OMOUSEDRAGGED:     return @"OMOUSEDRAGGED";
        case /*10*/NX_KEYDOWN:           return @"KEYDOWN";
        case /*11*/NX_KEYUP:             return @"KEYUP";
        case /*12*/NX_FLAGSCHANGED:      return @"FLAGSCHANGED";
        case /*13*/NX_KITDEFINED:        return @"KITDEFINED";
        case /*14*/NX_SYSDEFINED:        return @"SYSDEFINED";
        case /*15*/NX_APPDEFINED:        return @"APPDEFINED";
        case /*22*/NX_SCROLLWHEELMOVED:  return @"SCROLLWHEELMOVED";
        case /*28*/NX_ZOOM:              return @"ZOOM";
        case /*23*/NX_TABLETPOINTER:     return @"TABLETPOINTER";
        case /*24*/NX_TABLETPROXIMITY:   return @"TABLETPROXIMITY";
        default:                         return stringf(@"%u", type);
    }
}
NSString *CGEventField_Description(CGEventField field) {
    switch (field) {
        case kCGMouseEventNumber:/*0*/                                            return @"Mouse_Number";
        case kCGMouseEventClickState:/*1*/                                        return @"Mouse_ClickState";
        case kCGMouseEventPressure:/*2*/                                          return @"Mouse_Pressure";
        case kCGMouseEventButtonNumber:/*3*/                                      return @"Mouse_ButtonNumber";
        case kCGMouseEventDeltaX:/*4*/                                            return @"Mouse_DeltaX";
        case kCGMouseEventDeltaY:/*5*/                                            return @"Mouse_DeltaY";
        case kCGMouseEventInstantMouser:/*6*/                                     return @"Mouse_InstantMouser";
        case kCGMouseEventSubtype:/*7*/                                           return @"Mouse_Subtype";
        case kCGKeyboardEventAutorepeat:/*8*/                                     return @"Keyboard_Autorepeat";
        case kCGKeyboardEventKeycode:/*9*/                                        return @"Keyboard_Keycode";
        case kCGKeyboardEventKeyboardType:/*10*/                                  return @"Keyboard_KeyboardType";
        case kCGScrollWheelEventDeltaAxis1:/*11*/                                 return @"ScrollWheel_DeltaAxis1";
        case kCGScrollWheelEventDeltaAxis2:/*12*/                                 return @"ScrollWheel_DeltaAxis2";
        case kCGScrollWheelEventDeltaAxis3:/*13*/                                 return @"ScrollWheel_DeltaAxis3";
        case kCGScrollWheelEventFixedPtDeltaAxis1:/*93*/                          return @"ScrollWheel_FixedPtDeltaAxis1";
        case kCGScrollWheelEventFixedPtDeltaAxis2:/*94*/                          return @"ScrollWheel_FixedPtDeltaAxis2";
        case kCGScrollWheelEventFixedPtDeltaAxis3:/*95*/                          return @"ScrollWheel_FixedPtDeltaAxis3";
        case kCGScrollWheelEventPointDeltaAxis1:/*96*/                            return @"ScrollWheel_PointDeltaAxis1";
        case kCGScrollWheelEventPointDeltaAxis2:/*97*/                            return @"ScrollWheel_PointDeltaAxis2";
        case kCGScrollWheelEventPointDeltaAxis3:/*98*/                            return @"ScrollWheel_PointDeltaAxis3";
        case kCGScrollWheelEventScrollPhase:/*99*/                                return @"ScrollWheel_ScrollPhase";
        case kCGScrollWheelEventScrollCount:/*100*/                               return @"ScrollWheel_ScrollCount";
        case kCGScrollWheelEventMomentumPhase:/*123*/                             return @"ScrollWheel_MomentumPhase";
        case kCGScrollWheelEventInstantMouser:/*14*/                              return @"ScrollWheel_InstantMouser";
        case kCGTabletEventPointX:/*15*/                                          return @"Tablet_PointX";
        case kCGTabletEventPointY:/*16*/                                          return @"Tablet_PointY";
        case kCGTabletEventPointZ:/*17*/                                          return @"Tablet_PointZ";
        case kCGTabletEventPointButtons:/*18*/                                    return @"Tablet_PointButtons";
        case kCGTabletEventPointPressure:/*19*/                                   return @"Tablet_PointPressure";
        case kCGTabletEventTiltX:/*20*/                                           return @"Tablet_TiltX";
        case kCGTabletEventTiltY:/*21*/                                           return @"Tablet_TiltY";
        case kCGTabletEventRotation:/*22*/                                        return @"Tablet_Rotation";
        case kCGTabletEventTangentialPressure:/*23*/                              return @"Tablet_TangentialPressure";
        case kCGTabletEventDeviceID:/*24*/                                        return @"Tablet_DeviceID";
        case kCGTabletEventVendor1:/*25*/                                         return @"Tablet_Vendor1";
        case kCGTabletEventVendor2:/*26*/                                         return @"Tablet_Vendor2";
        case kCGTabletEventVendor3:/*27*/                                         return @"Tablet_Vendor3";
        case kCGTabletProximityEventVendorID:/*28*/                               return @"TabletProximity_VendorID";
        case kCGTabletProximityEventTabletID:/*29*/                               return @"TabletProximity_TabletID";
        case kCGTabletProximityEventPointerID:/*30*/                              return @"TabletProximity_PointerID";
        case kCGTabletProximityEventDeviceID:/*31*/                               return @"TabletProximity_DeviceID";
        case kCGTabletProximityEventSystemTabletID:/*32*/                         return @"TabletProximity_SystemTabletID";
        case kCGTabletProximityEventVendorPointerType:/*33*/                      return @"TabletProximity_VendorPointerType";
        case kCGTabletProximityEventVendorPointerSerialNumber:/*34*/              return @"TabletProximity_VendorPointerSerialNumber";
        case kCGTabletProximityEventVendorUniqueID:/*35*/                         return @"TabletProximity_VendorUniqueID";
        case kCGTabletProximityEventCapabilityMask:/*36*/                         return @"TabletProximity_CapabilityMask";
        case kCGTabletProximityEventPointerType:/*37*/                            return @"TabletProximity_PointerType";
        case kCGTabletProximityEventEnterProximity:/*38*/                         return @"TabletProximity_EnterProximity";
        case kCGEventTargetProcessSerialNumber:/*39*/                             return @"Target_ProcessSerialNumber";
        case kCGEventTargetUnixProcessID:/*40*/                                   return @"Target_UnixProcessID";
        case kCGEventSourceUnixProcessID:/*41*/                                   return @"Source_UnixProcessID";
        case kCGEventSourceUserData:/*42*/                                        return @"Source_UserData";
        case kCGEventSourceUserID:/*43*/                                          return @"Source_UserID";
        case kCGEventSourceGroupID:/*44*/                                         return @"Source_GroupID";
        case kCGEventSourceStateID:/*45*/                                         return @"Source_StateID";
        case kCGScrollWheelEventIsContinuous:/*88*/                               return @"ScrollWheel_IsContinuous";
        case kCGMouseEventWindowUnderMousePointer:/*91*/                          return @"Mouse_WindowUnderMousePointer";
        case kCGMouseEventWindowUnderMousePointerThatCanHandleThisEvent:/*92*/    return @"Mouse_WindowUnderMousePointerThatCanHandleThisEvent";
        case kCGEventUnacceleratedPointerMovementX:/*170*/                        return @"UnacceleratedPointerMovementX";
        case kCGEventUnacceleratedPointerMovementY:/*171*/                        return @"UnacceleratedPointerMovementY";
        case kCGScrollWheelEventMomentumOptionPhase:/*173*/                       return @"ScrollWheel_MomentumOptionPhase";
        case kCGScrollWheelEventAcceleratedDeltaAxis1:/*176*/                     return @"ScrollWheel_AcceleratedDeltaAxis1";
        case kCGScrollWheelEventAcceleratedDeltaAxis2:/*175*/                     return @"ScrollWheel_AcceleratedDeltaAxis2";
        case kCGScrollWheelEventRawDeltaAxis1:/*178*/                             return @"ScrollWheel_RawDeltaAxis1";
        case kCGScrollWheelEventRawDeltaAxis2:/*17*/                              return @"ScrollWheel_RawDeltaAxis2";

        case 55:                                                                  return @"Type";
        case 87:                                                                  return @"SenderID";

        default:                                                                  return stringf(@"%u", field);
    }
}

NSString *CGEvent_FieldValueDescription(CGEventRef event, CGEventField field) {

    double doubleValue = CGEventGetDoubleValueField(event, field);
    int64_t intValue = CGEventGetIntegerValueField(event, field);

    if (field == 87)      return stringf(@"0x%016llX", intValue);
    //else if (field == 89) return stringf(@"%f", FixedToFloat(intValue)); /// Looks like subpixel X/Y mouse deltas but not sure.
    //else if (field == 90) return stringf(@"%f", FixedToFloat(intValue));
    else {
        if (doubleValue == intValue) return stringf(@"%lld", intValue);
        else                         return stringf(@"%.2f", doubleValue);

    }
}

static CGEventRef __nullable eventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef  event, void * __nullable userInfo) {

    if (type == kCGEventTapDisabledByTimeout) { CGEventTapEnable(_eventTap, true); return event; }
    if (type == kCGEventTapDisabledByUserInput) { return event; }

    /// Print events
    ///     Findings: Universal control events from other MacBook arrive at the earliest `kCGHIDEventTap` - MMF is already receiving them [Oct 2026]
    if ((0))
        mflog("type: %d", type);

    /// Dump events to spot differences between real and universal control events
    ///     Findings: [Oct 2026]
    ///         Didn't look super close - they mostly look the same except for the `senderID`, which, for Universal Control events is a
    ///         `IOHIDEventSystem` service's "`RegistryID`" (See `hidutil list`) but doesn't actually appear as an entry in the IORegistry (See `ioreg` or `notes repo > ioreggg.m`)
    ///     Conclusion for MMF: §afterNoGCDTodo [Oct 2026]
    ///         MMF should use `IOHIDEventSystemClient` and `IOHIDServiceClient` APIs instead of `IOHIDManager` and `IOHIDDevice` - they mostly work the same
    ///         but they also work for non-IOService-backed devices (like the virtual devices created by universal control - not sure there are any others)
    ///         -> The currently-not-yet-used `PointerSpeed.m` stuff already uses `IOHIDEventSystemClient` APIs -> we could unify this §afterNoGCDTodo [Oct 2026]
    ///         Other interesting stuff: [Oct 2026]
    ///             - Opus 5.5 says the properties for `IOService`-backed `IOHIDServiceClients` are mostly synced/passed through with the underlying `IOService`.
    ///             - Interesting Opus 5.5 finding: It says `IOHIDEventSystem` is part of IOKit framework but runs in WindowServer process - sort of aggregating/post-processing the IOHIDEvents from all the IORegistry drivers before converting them to CGEvents. [Oct 2026]
    ///     Findings from the other side (this code here ran on the computer controlled *by* Universal Control)
    ///         As soon as the cursor hops to the other computer (and thereby starts Universal Control), CGEventTap goes completely dead, even at the earliest tap-point (`kCGHIDEventTap`/`kCGHeadInsertEventTap`)
    ///             -> So Universal Control must intercept before the CGEventTaps, which sorta fits the `IOHIDEventSystemClient` stuff we observed on the *controlled* computer above [Oct 2026]
    if ((1)) {
        NSMutableString *eventDescription = [NSMutableString new];
        {
            static NSMutableDictionary *seenFields = nil;
            if (!seenFields) seenFields = [NSMutableDictionary new];

            [eventDescription appendFormat: @"Event %d (%@):\n", type, CGEventType_Description(type)];

            for range(i, 256) {
                double doubleValue = CGEventGetDoubleValueField(event, i);
                int64_t intValue   = CGEventGetIntegerValueField(event, i);

                NSMutableSet *seenFields_ = seenFields[@(type)];
                if (doubleValue || intValue) {
                    if (!seenFields_) {
                        seenFields_ = [NSMutableSet new];
                        seenFields[@(type)] = seenFields_;
                    }
                    [seenFields_ addObject: @(i)];
                }

                if (![seenFields_ containsObject: @(i)]) continue;

                [eventDescription appendFormat: @"    %@ (%d): %@\n", [CGEventField_Description(i) stringByPaddingToLength: 30 withString: @" " startingAtIndex: 0], i, CGEvent_FieldValueDescription(event, i)];
            }

            extern CFTypeRef SLEventCopyIOHIDEvent(CGEventRef event);
            id iohidEvent = CFBridgingRelease(SLEventCopyIOHIDEvent(event));
            [eventDescription appendFormat: @"    IOHIDEvent:\n%@\n", iohidEvent];

        }

        mflog("%@", eventDescription);
    }

    return event;
}
int universalControlTest_Start(void) {

    _eventTap = CGEventTapCreate(kCGSessionEventTap, kCGTailAppendEventTap, kCGEventTapOptionDefault, kCGEventMaskForAllEvents, eventTapCallback, /*userInfo*/NULL);
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, /*order*/0);
    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, kCFRunLoopCommonModes);

    while (1) CFRunLoopRun();

    return 0;
}
