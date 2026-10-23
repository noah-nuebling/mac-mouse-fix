//
// --------------------------------------------------------------------------
// MFEventTap.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#pragma once
#import <Foundation/Foundation.h>
#import <CoreGraphics/CGEvent.h>

@interface MFEventTap : NSObject

    #define kMFEventTapLocation kCGSessionEventTap

    typedef NSString MFEventListenerID;

    typedef int64_t MFEventType;
        #define kMFEventType_StopListening              ((MFEventType)0)

        #define kMFEventType_Modifier                   ((MFEventType)1 << 1)
        #define kMFEventType_Keystroke                  ((MFEventType)1 << 2)

        #define kMFEventType_TrackingSensor             ((MFEventType)1 << 3)
        #define kMFEventType_ScrollWheel                ((MFEventType)1 << 4)
        #define kMFEventType_Experiment                 ((MFEventType)1 << 5) /// [Oct 2026] Experimenting with other CGEventTypes is a little more difficult due to this abstraction

        #define kMFEventType_Button(buttonIndex)        ((MFEventType)1 << ((buttonIndex) + _kMFEventType_ButtonShift))
        #define _kMFEventType_ButtonShift 32
        #define _kMFEventType_ButtonMask  0xFFFFFFFF


    typedef void (*MFEventTapCallback)(void *context, MFEventType eventType, CGEventRef *eventPtr);

    + (void) registerListener: (MFEventListenerID *)listenerID forEvents: (MFEventType)events callback: (MFEventTapCallback)callback context: (void *)context;
    + (bool) isEnabledForListener: (MFEventListenerID *)listenerID;
    + (void) enable: (bool)enable forListener: (MFEventListenerID *)listenerID;

    + (void) postCGEvent: (CGEventRef)cgEvent;
    + (void) postCGEventBeforeAllSessionTaps: (CGEventRef)cgEvent;

    + (NSString *) descriptionForListener: (MFEventListenerID *)listenerID;

@end
