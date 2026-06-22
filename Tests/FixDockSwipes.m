//
// --------------------------------------------------------------------------
// FixDockSwipes.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// macOS 27 (Beta 2) broke DockSwipe simulation in MMF
///     -> This code code explores solution.
///     (Note: We have a proper CGEvent reverse engineering  repo, but doing it from scratch felt more fun / lower friction.)

#import "MFHIDEventImports.h"
//#import "Definitions.h"
//#import "Extensions.h"

#import "IOHIDEventTypes.h"

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

#define mflog(x...) printf("%s\n", [NSString stringWithFormat: x].UTF8String);

static CFMachPortRef eventTap = NULL;

@implementation NSObject (Stuff) /// Put this in a category to loosen declaration order for the C functions

void FixDockSwipes_Start(void) {
    eventTap = CGEventTapCreate(kCGHIDEventTap, kCGTailAppendEventTap, kCGEventTapOptionDefault, kCGEventMaskForAllEvents, eventTapCallback, /*userInfo*/NULL);
    CFRunLoopSourceRef source = CFMachPortCreateRunLoopSource(NULL, eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetMain(), source, kCFRunLoopCommonModes);
    CGEventTapEnable(eventTap, true);
}

CGEventRef eventTapCallback(CGEventTapProxy  proxy, CGEventType type, CGEventRef  event, void * __nullable userInfo) {
    
    if (type == kCGEventTapDisabledByTimeout) CGEventTapEnable(eventTap, true);
    
    if (type == 29 || type == 30) { /// These events are emitted by Dock Swipes
        
        /// Log
        if ((0)) mflog(@"eventType: %d", type);
        
        /// Block events - still works!
        if ((0)) return NULL;
        
        /// Copy events and send them async - still works!
        if ((0)) {
            CGEventRef eventCopy = CGEventCreateCopy(event);
            
            [NSRunLoop.mainRunLoop performBlock: ^{
                CGEventPost(kCGSessionEventTap, eventCopy);
                CFRelease(eventCopy);
            }];
            
            return NULL;
        }
        
        /// List all fields that have a value at all
        if ((0)) {
            event = CGEventCreateCopy(event); /// Copy since that already removes some fields and metadata, IIRC
            CFAutorelease(event);
            
            static NSMutableDictionary *dict = nil;
            if (!dict) dict = [NSMutableDictionary new];
            
            NSMutableSet *fields = dict[@(type)];
            if (!fields) {
                fields = [NSMutableSet new];
                dict[@(type)] = fields;
            }
            
            for (CGEventField f = 0; f < 256; f++) {
                if (CGEventGetIntegerValueField(event, f) || CGEventGetDoubleValueField(event, f)) {
                    [fields addObject: @(f)];
                }
            }
            
            mflog(@"type: %d, seenFields: %@", type, [fields.allObjects sortedArrayUsingSelector: @selector(compare:)]);
            
            return NULL;
            
        }
        
        /// Delete all fields from the event until things break
        if ((0)) {
            event = CGEventCreateCopy(event); /// Copy since that already removes some fields and metadata, IIRC
            if ((0)) CFAutorelease(event);
            
            if ((1))
            for (CGEventField f = 0; f < 256; f++) {
                
                /// Preserve these fields
                if (type == 30)
                if (0
                    //|| f == 39
                    //|| f == 40
                    //|| f == 45
                    //|| f == 50
                    || f == 55      /// Only necessary field. (CGEventType, I think) Though it's kinda janky right now, maybe the other fields did something useful? (Forgot to test vertical and pinch Swipes)
                    //|| f == 58
                    //|| f == 85
                    //|| f == 87
                    //|| f == 101
                    //|| f == 110
                    //|| f == 113
                    //|| f == 114
                    //|| f == 115
                    //|| f == 116
                    //|| f == 117
                    //|| f == 118
                    //|| f == 119
                    //|| f == 120
                    //|| f == 123
                    //|| f == 124
                    //|| f == 125
                    //|| f == 126
                    //|| f == 129
                    //|| f == 130
                    //|| f == 132
                    //|| f == 134
                    //|| f == 135
                    //|| f == 136
                    //|| f == 138
                    //|| f == 139
                    //|| f == 140
                    //|| f == 164
                    //|| f == 165
                    //|| f == 169
                ) continue;
                
                if (type == 29) /// We can delete ALL the fields and it still works! (Though this might be making it choppier / jankier.) -> Suggests DockSwipes are now based on private metadata attached to the CGEvents, not eventFields
                if (0
                    //|| f == 39
                    //|| f == 40
                    //|| f == 45
                    //|| f == 50
                    //|| f == 55
                    //|| f == 58
                    //|| f == 85
                    //|| f == 87
                    //|| f == 101
                    //|| f == 110
                    //|| f == 113
                    //|| f == 114
                    //|| f == 115
                    //|| f == 116
                    //|| f == 117
                    //|| f == 118
                    //|| f == 119
                    //|| f == 123
                    //|| f == 132
                    //|| f == 139
                    //|| f == 142
                    //|| f == 143
                    //|| f == 144
                    //|| f == 147
                    //|| f == 148
                    //|| f == 164
                    //|| f == 165
                    //|| f == 169
                ) continue;
                
                /// Delete all the other fields
                CGEventSetIntegerValueField(event, f, 0);
                CGEventSetDoubleValueField(event, f, 0.0);
            }
            
            if (type == 29) return NULL; /// Still works, even when we remove type == 29 events from the eventStream entirely
            //if (type == 30) return NULL; /// Removing type == 30 events breaks things.
            
            return event;
        }
        
        /// Explore private data attached to type == 30 events
        if ((1)) {
            return exploreHIDEvents(event);
        }
    }
    
    return event;
}

CGEventRef exploreHIDEvents(CGEventRef event) {
    
    /// Prep
    CGEventType type = CGEventGetType(event);
    assert(type == 29 || type == 30);
    if (type == 29) return NULL; /// type == 29 events are not necessary
    
    /// Get IOHIDEventRef from the type == 30 event
    extern IOHIDEventRef CGEventCopyIOHIDEvent(CGEventRef event);
    IOHIDEventRef iohidEvent = CGEventCopyIOHIDEvent(event);
    
    /// Bridge to objc overlay (HIDEvent)
    HIDEvent *hidEvent = (__bridge id)iohidEvent;
    
    /// Print the HID event - shows all the DockSwipe values!
    mflog(@"hidEvent: %@", [hidEvent description]);
    
    /// Copy the HIDEvent by manually setting fields
    HIDEvent *copy; {
        /// Try accessor methods – None available for DockSwipes
        if ((0)) {
            copy = [[HIDEvent alloc] initWithType: hidEvent.type timestamp: hidEvent.timestamp senderID: hidEvent.senderID];
            //copy.flags = hidEvent.flags; /// Doesn't exist??
            //copy.phase = hidEvent.phase; /// Doesn't exist??
            //copy.flavor = hidEvent.flavor; /// Doesn't exist??
        }
        
        /// Find DockSwipe eventFields via enumerateFieldsWithBlock: – Works!
        ///     ... duh, these are already defined in `MFHIDEventImports.h`
        if ((0)) {
            //mflog(@"fieldDescription: %@:", [hidEvent mf_fieldDescription]);
            //#define kIOHIDEventFieldDockSwipePositionX  1507331     /*, fieldType: 4, base: 1, readonly: 0, name: )*/
            //#define kIOHIDEventFieldDockSwipePositionY  1507332     /*, fieldType: 4, base: 1, readonly: 0, name: )*/
            //#define kIOHIDEventFieldDockSwipePositionZ  1507334     /*, fieldType: 4, base: 1, readonly: 0, name: )*/
            //#define kIOHIDEventFieldDockSwipeMask       1507328     /*, fieldType: 1, base: 1, readonly: 0, name: )*/
            //#define kIOHIDEventFieldDockSwipeMotion     1507329     /*, fieldType: 1, base: 1, readonly: 0, name: )*/
            //#define kIOHIDEventFieldDockSwipeFlavor     1507333     /*, fieldType: 1, base: 1, readonly: 0, name: )*/
            //#define kIOHIDEventFieldDockSwipeProgress   1507330     /*, fieldType: 4, base: 1, readonly: 0, name: )*/
        }
        
        /// Print the eventField values (Recreating [hidEvent description], roughly)
        ///     Notes:
        ///         - All the EventBase values can be inferred from `HIDEventIvar.h` I think (In IOKitUser)
        ///         - The IOHIDEvent... C accessors have more finegrained accessors than the HIDEvent accessors (which just call the IOHIDEvent accessors)
        if ((1)) {
            #define kMicrosecondScale 1000 /** Not sure */
            extern CFStringRef IOHIDEventTypeGetName(IOHIDEventType eventType);
            extern uint64_t IOHIDEventGetTimeStampType(IOHIDEventRef iohidEvent);  /// Not sure what the return value is
            extern uint64_t IOHIDEventGetLatency(IOHIDEventRef iohidEvent, int scale); /// Not sure about types
            extern bool IOHIDEventIsAbsolute(IOHIDEventRef iohidEvent);                 /// Not sure what return value is
            extern IOHIDEventPhaseBits IOHIDEventGetPhase(IOHIDEventRef iohidEvent);      /// Also see -getPhaseFromOptions:
            
            mflog(@"DockSwipe: {EventBase: (timestamp: %ld, timestampType: %llu, latency: %llu, senderID: %lx, isAbsolute: %d, type: %@, options: %x, phase: %d), DockSwipe: ((x: %f, y: %f, z: %f), mask: %lx, motion: %lx, flavor: %lx, progress: %f)}"
                ,[hidEvent timestamp]
                ,IOHIDEventGetTimeStampType(iohidEvent) /// Might be part of `options`
                ,IOHIDEventGetLatency(iohidEvent, kMicrosecondScale)
                ,[hidEvent senderID]
                //,[hidEvent builtIn] /// No accessor for this, but the -description shows it. Part of `options`?
                ,IOHIDEventIsAbsolute(iohidEvent) /// 'valueType' (Relative or Absolute) || Might be part of `options`
                ,IOHIDEventTypeGetName([hidEvent type])
                ,[hidEvent options] /// Pretty sure this is 'Flags' in the description
                ,IOHIDEventGetPhase(iohidEvent) /// (This is a subset of the option/Flags bits) || No accessor for this, but the -description shows it.
                ,[hidEvent doubleValueForField: kIOHIDEventFieldDockSwipePositionX]
                ,[hidEvent doubleValueForField: kIOHIDEventFieldDockSwipePositionY]
                ,[hidEvent doubleValueForField: kIOHIDEventFieldDockSwipePositionZ]
                ,[hidEvent integerValueForField: kIOHIDEventFieldDockSwipeMask]
                ,[hidEvent integerValueForField: kIOHIDEventFieldDockSwipeMotion]
                ,[hidEvent integerValueForField: kIOHIDEventFieldDockSwipeFlavor]
                ,[hidEvent doubleValueForField: kIOHIDEventFieldDockSwipeProgress]
            );
        }
        
        /// Try to recreate the HIDEvent from scratch
        if ((1)) {
            
            bool kMinimal = true; /// Copy only the minimal set of data into the new HIDEvent (that still makes the gestures work)
            
            /// Create newEvent
            copy = [[HIDEvent alloc] initWithType: kIOHIDEventTypeDockSwipe timestamp: mach_absolute_time() senderID: 0xDEADF4C3];
            [copy setOptions: hidEvent.options];
            if ((!kMinimal)) [copy setDoubleValue: [hidEvent doubleValueForField: kIOHIDEventFieldDockSwipePositionX] forField: kIOHIDEventFieldDockSwipePositionX];
            if ((!kMinimal)) [copy setDoubleValue: [hidEvent doubleValueForField: kIOHIDEventFieldDockSwipePositionY] forField: kIOHIDEventFieldDockSwipePositionY];
            if ((!kMinimal)) [copy setDoubleValue: [hidEvent doubleValueForField: kIOHIDEventFieldDockSwipePositionZ] forField: kIOHIDEventFieldDockSwipePositionZ];
            if ((!kMinimal)) [copy setIntegerValue: [hidEvent integerValueForField: kIOHIDEventFieldDockSwipeMask] forField: kIOHIDEventFieldDockSwipeMask];
            [copy setIntegerValue: [hidEvent integerValueForField: kIOHIDEventFieldDockSwipeMotion] forField: kIOHIDEventFieldDockSwipeMotion];
            [copy setIntegerValue: [hidEvent integerValueForField: kIOHIDEventFieldDockSwipeFlavor] forField: kIOHIDEventFieldDockSwipeFlavor];
            [copy setDoubleValue: [hidEvent doubleValueForField: kIOHIDEventFieldDockSwipeProgress] forField: kIOHIDEventFieldDockSwipeProgress];
            
            IOHIDEventPhaseBits phase = ([hidEvent options] >> kIOHIDEventEventOptionPhaseShift) & kIOHIDEventEventPhaseMask;
            if (phase == kIOHIDEventPhaseEnded || phase == kIOHIDEventPhaseCancelled) {
                
                HIDEvent *child = hidEvent.children.firstObject;
                HIDEvent *childCopy = [[HIDEvent alloc] initWithType: kIOHIDEventTypeVelocity timestamp: mach_absolute_time() senderID: 0xDEADF4C3];
                
                double velocityX = [child doubleValueForField: kIOHIDEventFieldVelocityX];
                double velocityY = [child doubleValueForField: kIOHIDEventFieldVelocityY];
                double velocityZ = [child doubleValueForField: kIOHIDEventFieldVelocityZ];
                assert(velocityX == velocityY);
                assert(velocityZ == 0);
                
                [childCopy setDoubleValue: velocityX forField: kIOHIDEventFieldVelocityX];
                [childCopy setDoubleValue: velocityY forField: kIOHIDEventFieldVelocityY];
                if ((!kMinimal)) [childCopy setDoubleValue: velocityZ forField: kIOHIDEventFieldVelocityZ];
                
                [copy appendEvent: childCopy];
            }
        }
        
        /// Compare by printing
        if ((0)) mflog(@"%@\nvs.\n%@", hidEvent, copy);
    }
    
    /// Wrap the copied HIDEvent in a new CGEvent and replace the original event with the new event in the event stream
    ///     -> Gestures still work – we did it!
    if ((1)) {
        CGEventRef wrapper = CGEventCreate(/*source*/NULL);
        CGEventSetType(wrapper, 30);
        //CGEventSetIntegerValueField(wrapper, 55, 30/*NSEventTypeMagnify*/); /// ... I think field 55 is just the CGEventType ... (The MMF gesture simulation code is pretty confused about this)
        extern void SLEventSetIOHIDEvent(CGEventRef cgEvent, IOHIDEventRef iohidEvent);   /// Have to link SkyLight.framework to link this. CG-variant (CGEventSetIOHIDEvent) doesn't work.
        SLEventSetIOHIDEvent(wrapper, (__bridge void *)copy);
        return wrapper;
    }
        
    return event;
}

@end
