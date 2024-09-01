//
// --------------------------------------------------------------------------
// MFDataClass.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "SharedUtility.h"

///
/// Let's you easily declare objc dataclasses like this:
///     ```
///     MFDataClass(MFAddress, (MFDataProp(NSString *city)
///                             MFDataProp(NSString *street)
///                             MFDataProp(NSString *zipcode)))
///     ```
/// Or if you want to expose the class in an .h file:
///
///     In Header.h:
///         ```
///         MFDataClassHeader(MFAddress, (MFDataProp(NSString *city)
///                                       MFDataProp(NSString *street)
///                                       MFDataProp(NSString *zipcode)))
///         ```
///
///     In FileWhereDataClassImplementationsGo.m:
///         ```
///         MFDataClassImplementation(MFAddress)
///         ```
///
/// The resulting dataclass will be equatable, copyable, and de-/encodable.
///
/// Notes:
///     - We should consider replacing the remaps dict with this.
///         (Or maybe a nested class structure defined in swift would be even nicer, but not sure if fast and objc compatible.)

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Macros

/// Macros for user

#define MFDataClass(__className, __classProperties) \
    MFDataClassHeader(__className, __classProperties) \
    MFDataClassImplementation(__className) \

#define MFDataClassHeader(__className, __classProperties) \
    @interface __className : MFDataClassBase \
    UNPACK __classProperties \
    @end

#define MFDataClassImplementation(__className) \
    @implementation __className \
    @end

#define MFDataProp(__typeAndName) \
    @property (nonatomic, strong, readwrite, nullable) __typeAndName;

#pragma mark - Base superclass

@interface MFDataClassBase : NSObject<NSCopying, NSCoding>

@end


NS_ASSUME_NONNULL_END
