//
//  HIDEventBase.h
//  IOKitUser
//
//  Created by Matt Dekom on 9/11/18.
//

#ifndef HIDEventBase_h
#define HIDEventBase_h

#if __OBJC__

#import "HIDEventIvar.h"
#import <CoreFoundation/CoreFoundation.h>
#import <objc/NSObject.h>

@interface HIDEvent : NSObject {
@protected
    HIDEventStruct _event;
}

@end

#endif /* __OBJC__ */

#endif /* HIDEventBase_h */
