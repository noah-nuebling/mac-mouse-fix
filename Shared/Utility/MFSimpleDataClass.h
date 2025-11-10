//
//  MFSimpleDataClass.h
//  playground-oct-2025
//
//  Created by Noah Nübling on 10.11.25.
//

/**
 [Nov 2025]
     Reimplementation of MFDataClass.m but muchhh simpler. And easier to use.
     It lacks some stuff like specifying readonly members, or validating nullability when decoding. But none of that stuff is very useful I think. This gives like 99% of the value in a much nicer way. [Nov 2025]
        
    Gives you designated initializer syntax for objc-objects!
        This assumes that the ivar layout is the same as a c struct with the same members.
        Pretty sure this will work fine in practice.
            Evidence:
                - Works on all my computers in my testing.
                - https://alwaysprocessing.blog/2023/03/12/objc-ivar-abi
                    "Objective-C class instance variables in 32-bit versions of macOS have a "fragile" layout, meaning instance variables for this deployment target are accessed by their offset from the start of the class as if the instance variables throughout the class hierarchy were concatenated into a C struct"
                    -> I assume that historically, ivars were just implemented using structs, and any deviation is due to `Non-Fragile Instance Variables` feature which should only apply to dynamic libs in special cases. [Nov 2025]
 
     Original defined in `playground-oct-2025` [Nov 2025]
     Should perhaps replace MFDataClass.m with this at some point. [Nov 2025]

     Usage examples:
        Declaration:
            .h file:
                ```
                mfdata_cls_h(Person,
                    NSString *name;
                    int age;
                    id mystery;
                );
                ```
            .m file:
                ```
                mfdata_cls_m(Person);
                ```
            Or, if you only need the dataclass in one .m file you can avoid splitting the declaration up:
                ```
                mfdata_cls(Person,
                    NSString *name;
                    int age;
                    id mystery;
                );
                ```
        Instance creation:
            ```
            mfdata_new(Person,
                .name = @"Bernd",
                .age = 67,
                .mystery = @"likes long walks in the park under the starry autumn sky"
            );
            ```
            You can also omit fields to have them be zero-initialized (the syntax works just like a designated initializer for a struct [Nov 2025]
        ```
 */

#pragma once

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface MFSimpleDataClassBase : NSObject <NSCoding, NSSecureCoding, NSCopying, NSMutableCopying> @end

#define mfdata_cls(classname, structfields...) \
    mfdata_cls_h(classname, structfields) \
    mfdata_cls_m(classname)

#define mfdata_cls_h(classname, structfields...) \
    @interface classname : MFSimpleDataClassBase { @public structfields } @end \
    struct classname { structfields };

#define mfdata_cls_m(classname) \
    @implementation classname @end \

#define mfdata_new(classname, vals...) ({ \
    auto _struct = (struct classname) { vals }; \
    auto _result = [classname new]; \
    auto _isaSize = sizeof(Class); \
    if (class_getInstanceSize([classname class]) != (sizeof(struct classname) + _isaSize)) abort(); /** This validation is the only reason to import `<objc/runtime.h>` here. [Nov 2025] */\
    void *_ivarStartPtr = (((__bridge void *)_result) + _isaSize); \
    *(struct classname *)_ivarStartPtr = _struct; /** Seems like ARC correctly retains the assigned objects here. Very hacky but should work as long as the struct fields and object's ivars have the exact same memory layout. [Nov 2025] */\
    _result; \
})
