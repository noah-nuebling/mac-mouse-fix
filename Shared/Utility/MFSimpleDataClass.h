//
//  MFSimpleDataClass.h
//  playground-oct-2025
//
//  Created by Noah Nübling on 10.11.25.
//

/**
 [Nov 2025]
    Comparison with MFDataClass.m:
        Reimplementation of MFDataClass.m but muchhh simpler. And easier to use.
         It lacks some stuff like specifying readonly members, or validating nullability when decoding. But none of that stuff is very useful I think. This gives like 99% of the value in a much nicer way. [Nov 2025]
            
        Gives you designated initializer syntax for objc-objects!
            This assumes that the ivar layout is the same as a c struct with the same members.
            Pretty sure this will work fine in practice.
                Evidence:
                    - Works on all my computers (2018 Mac Mini, M1 MBA) on (macOS 11 Big Sur - macOS 26 Tahoe) (Also tested `mfdata_subcls_h()`) [Nov 2025]
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
                `mfdata_cls_m(Person);`
        Instance creation:
            ```
            mfdata_new(Person,
                .name = @"Bernd",
                .age = 67,
                .mystery = @"likes long walks in the park under the starry autumn sky"
            );
            ```
            You can also omit fields to have them be zero-initialized (the syntax works just like a designated initializer for a struct [Nov 2025]
            
    Subclasses
        When declaring a subclass, everything works the same, except you have to use `mfdata_subcls_h` instead of `mfdata_cls_h`.
        Usage Example: (.h file:)
            ```
            mfdata_subcls_h(Grandpa, Person,
                int grandchildren;
            );
            ```
        Explanation:
            -> `Grandpa` has the same ivars as `Person`, plus `int grandchildren;`
            -> `[grandpa isKindOfClass: [Person class]]` will be true.
            ->  You can cast a grandpa to `(Person *)` and still safely access the ivars declared in `Person`
        Discussion:
            Not sure we'll need this. Don't overengineer things like we did with the original `MFDataClass.m` [Nov 2025]
        
    Downside:
        Just found out Swift can't access ivars.
        Solution ideas:
            - We can add compatibility when needed by writing (SwiftCompat) categories with getter-methods.
            - Use KVC from Swift and treat it like a dictionary
            - Don't use the macros, and just create a `MFSimpleDataClassBase` in plain objc using @property
            - Just avoid using Swift (I really don't like it but 30% of the codebase is Swift atm and it works fine [Nov 2025])
            - Could use FOR_EACH metamacro to have `mfdata_cls_h` create @property definitions.
                -> Doesn't work, properties seem to create a different ivar order which breaks our `mfdata_new` impl. See `playground-oct-2025` [Nov 2025]
                    -> We'd have to replace `mfdata_new` with macro-generate initializers, too -> Much more complex.
 */

#pragma once

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface MFSimpleDataClassBase : NSObject <NSCoding, NSSecureCoding, NSCopying, NSMutableCopying> @end

/// Cls

#define mfdata_cls_h(classname, structfields...) \
    @interface classname : MFSimpleDataClassBase { @public structfields } @end \
    struct classname { structfields };

#define mfdata_cls_m(classname) \
    @implementation classname @end \

/// Subcls
///     Use `-fms-extensions` and `-Wno-microsoft-anon-tag` compilerflags to use this.

#define mfdata_subcls_h(classname, supclassname, structfields...) \
    @interface classname : supclassname { @public structfields } @end \
    struct classname { struct supclassname; structfields }; /** Concating structs like this requires `-fms-extensions` and triggers `-Wno-microsoft-anon-tag` */

/// New

#define mfdata_new(classname, vals...) ({ \
    auto _struct = (struct classname) { vals }; \
    auto _result = [classname new]; \
    auto _isaSize = sizeof(Class); \
    if (class_getInstanceSize([classname class]) != (sizeof(struct classname) + _isaSize)) abort(); /** This validation is the only reason to import `<objc/runtime.h>` here. [Nov 2025] */\
    void *_ivarStartPtr = (((__bridge void *)_result) + _isaSize); \
    *(struct classname *)_ivarStartPtr = _struct; /** Seems like ARC correctly retains the assigned objects here. Very hacky but should work as long as the struct fields and object's ivars have the exact same memory layout. [Nov 2025] */\
    _result; \
})
