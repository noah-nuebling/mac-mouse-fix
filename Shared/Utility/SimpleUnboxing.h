//
// --------------------------------------------------------------------------
// SimpleUnboxing.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Apple has deprecated the standard functions for unboxing their foundational datatypes into c-arrays
///     with the comment "This method is unsafe because it could potentially cause buffer overruns."
///     I disagree that they are "unsafe". I think these are safe and convenient, so we're "un-deprecating" these methods here by re-declaring them in a category.
///
/// As of [Feb 2025] we've "un-deprecated" the unboxing methods for:
///     - NSDictionary
///     - NSArray
///     - NSString
///     - NSData
///     - NSValue
///  ... by copying Apple's declarations and swapping out the API_DEPRECATED() for API_AVAILABLE() macros.
///
/// You have to import this header for the deprecation warnings to go away.
///
/// Why even 'unbox' stuff to the stack?
///     Should be very fast, and I often find it more ergonomic and clear to deal with C arrays than with objects.

#import <Foundation/Foundation.h>

@interface NSDictionary<KeyType, ObjectType> (SimpleUnboxing)
    - (void)getObjects:(ObjectType _Nonnull __unsafe_unretained [_Nullable])objects andKeys:(KeyType _Nonnull __unsafe_unretained [_Nullable])keys  NS_SWIFT_UNAVAILABLE("Use 'allKeys' and/or 'allValues' instead") API_AVAILABLE(macos(10.0), ios(2.0), watchos(2.0), tvos(9.0));
@end

@interface NSArray<ObjectType> (SimpleUnboxing)
    - (void)getObjects:(ObjectType _Nonnull __unsafe_unretained [_Nonnull])objects NS_SWIFT_UNAVAILABLE("Use 'as [AnyObject]' instead") API_AVAILABLE(macos(10.0), ios(2.0), watchos(2.0), tvos(9.0));
@end

@interface NSString (SimpleUnboxing)
    - (void)getCharacters:(unichar *_Nonnull)buffer API_AVAILABLE(macos(10.0), ios(2.0), watchos(2.0), tvos(9.0));
    ///     ^ Apples header is missing the `API_DEPRECATED()` macro, but the online documentation lists it as deprecated (As of [Feb 2025])
@end

@interface NSData (SimpleUnboxing)
    - (void)getBytes:(void *_Nullable)buffer API_AVAILABLE(macos(10.0), ios(2.0), watchos(2.0), tvos(9.0));
    ///     ^ You can also use -[bytes], to access the bytes without copying them to the stack
@end

@interface NSValue (SimpleUnboxing)
    - (void)getValue:(void *_Nonnull)value API_AVAILABLE(macos(10.0), ios(2.0), watchos(2.0), tvos(9.0));
@end

/// -----------------------------------

@interface NSOrderedSet<ObjectType> (SimpleUnboxing)
    /// Doesn't have a 'simple' unboxing method by Apple, we could add one.
@end

@interface NSIndexSet (SimpleUnboxing)
    /// Doesn't have a 'simple' unboxing method by Apple, we could add one.
@end
