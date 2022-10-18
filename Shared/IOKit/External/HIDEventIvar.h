//
//  HIDEventIvar.h
//  IOKitUser
//
//  Created by dekom on 9/11/18.
//

#ifndef HIDEventIvar_h
#define HIDEventIvar_h

#import "hidobjcbase.h"
#import <CoreFoundation/CoreFoundation.h>
#import <objc/objc.h> // for objc_object

/*
 * This is where we define the ivars that will be used by both the CF
 * IOHIDEventRef, and the objc HIDEvent. The variables must be the same between
 * the two objects to ensure proper bridging.
 */

#define HIDEventIvar \
uint64_t                timeStamp; /* Clock ticks from mach_absolute_time */ \
uint64_t                senderID; \
uint64_t                typeMask; \
uint32_t                options; \
uint8_t                 *attributeData; \
void                    *context; \
CFMutableDictionaryRef  attachments; \
CFTypeRef               sender; \
CFMutableArrayRef       children; \
IOHIDEventRef           parent; \
CFIndex                 attributeDataLength; \
CFIndex                 eventCount; \
IOHIDEventData          *eventData;

typedef struct  {
    HIDEventIvar
} HIDEventStruct;

#endif /* HIDEventIvar_h */
