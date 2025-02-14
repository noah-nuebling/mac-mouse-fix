//
// --------------------------------------------------------------------------
// MFCoding.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

@interface MFCoding : NSObject

typedef enum: CFIndex {
    
    /// NSKeyedArchiver encodings
    ///     Archive is NSData
    ///     Note: The resulting NSData actually represents a plist, too, but NSKeyedArchiver uses compression and deduplication, making the plist hard to decipher as a human compared to MFPlistEncoder
    kMFEncoding_NSKeyed_XML              = kCFPropertyListXMLFormat_v1_0,     /// The resulting NSData contains an XML string representing a plist
    kMFEncoding_NSKeyed_Binary           = kCFPropertyListBinaryFormat_v1_0,  /// The resulting NSData contains binary data representing a plist
    
    /// MFPlistEncoder encoding
    ///     Archive is a plist object-graph
    kMFEncoding_MFPlist                 = kCFPropertyListBinaryFormat_v1_0 + 99, /// Since the kCFPropertyList constants are spaced apart by 100, 99 should avoid conflicts. (I'm overthinking this.)
    
} MFEncoding;

id _Nullable MFEncode(NSObject<NSCoding> *_Nonnull codable, BOOL requireSecureCoding, MFEncoding outputArchiveFormat) NS_REFINED_FOR_SWIFT; 
id<NSCoding> _Nullable MFDecode(id _Nonnull archive, BOOL requireSecureCoding, NSSet<Class> *_Nullable expectedClasses, MFEncoding inputArchiveFormat) NS_REFINED_FOR_SWIFT;

@end
