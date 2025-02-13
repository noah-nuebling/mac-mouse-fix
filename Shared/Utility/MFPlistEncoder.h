//
// --------------------------------------------------------------------------
//MFPlistEncoder.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "NSCoderErrors.h"

#pragma mark - Shared stuff for encoding/decoding

/// About MFPlistEncoder / MFPlistDecoder [Feb 2025]
///     What: Converts between any object-graph and a "plist-object graph" consisting only of one of the 7 plist types. (Which are documented here: https://developer.apple.com/documentation/corefoundation/cfpropertylistref?language=objc)
///     How: All non-plist objects in the graph are converted to an NSDictionary holding the internal state, plus the class-name of the object.
///     Why: We wanna store our MFDataClass objects in our config.plist in a *human readable* way.
///         On human-readable: The structure of the original object-graph is directly reflected in the plist-object graph. With the non-plist objects simply being replaced by NSDictionary. So it's easy to inspect and debug the archive and to embed it into our MMF config.plist file.
///         Alternative: We could also use NSKeyedArchiver and convert the resulting NSData into a plist using NSPropertyListSerialization, and then put that inside config.plist. However, the resulting plist is not easily human-readable, since it's using compression and deduplication techniques.
///         Other alternatives:
///             - We could move to non-plist data storage like CoreData or storing plain NSData of our object archives. However, that's much less human-readable and more complicated.
///             - We could only use plist types (NSDictionary and NSArray) to model our data. But that kinda sucks, and so we introduced MFDataClass to replace NSDictionary in our data-models.
///     Is this overengineered?
///         Maybe? Probably? We only expect to use this for MFDataClass, and we only expect to ever put plist types and other MFDataClass instances into an MFDataClass (at least for classes we'd wanna serialize.)
///         There might have been simpler ways to achieve this than to write this pretty general plist-encoder/decoder. But I'm not sure.
///
///     This is not a complete NSCoder implementation: [Feb 2025]
///     - There are some methods that NSCoder subclasses should support, but our MFPlistEncoder/MFPlistDecoder don't. E.g.:
///         - All NSCoders are supposed to support non-keyed-coding, but using it in initWithCoder: with keyed archivers is discouraged.
///             > For MFDataClass we don't need that support. So won't implement unless necessary.
///         - For NSData, a custom coder should implement special encoding/decoding methods
///             > But we just store NSData plain in our archive plist, so we don't need this.
///
///     Also see:
///         - Apple reference on "Archives and Serialization":
///           https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Archiving/Articles/serializing.html#//apple_ref/doc/uid/20000952-BABBEJEE

/// Also see:
///     - `MFCoding.m` for more on NSCoder.

#define MFDataClass_DictArchiveKey_ClassName    @"___MFPlist_ClassName___"      /// Key used in our plist archives to specify the class of the object that a dictionary encodes
#define kkMFPlist_Nil                           @"___kMFPlist_Nil___"           /// This string encodes nil in our plist archives. Alternatives: `nil` can't be stored in NSArray/NSDictionary at all. `NSNull` is not a plist type.

#define isNSCoding(x) /** This should be faster and logically equivalent to directly checking NSCoder protocol conformance.*/\
    [(x) respondsToSelector: @selector(initWithCoder:)]

bool MFPlistIsValidNode(id _Nullable obj);                                      /// Utility function used for encoding and decoding

#pragma mark - Encoder

@interface MFPlistEncoder : NSCoder_WithNiceErrors

- (id _Nullable) encodedPlist; /// After encoding, the result will be stored here.
- (instancetype _Nullable) initRequiringSecureCoding: (BOOL)requiresSecureCoding failurePolicy: (NSDecodingFailurePolicy)failurePolicy;

@end
