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
    kMFEncoding_NSData_OpenStep        =     kCFPropertyListOpenStepFormat,
    kMFEncoding_NSData_XML             =     kCFPropertyListXMLFormat_v1_0,
    kMFEncoding_NSData_Binary          =     kCFPropertyListBinaryFormat_v1_0,
    
    /// MFDataClassDictionary encoding
    kMFEncoding_NSDictionary,
} MFEncoding;

id _Nullable MFEncode(NSObject<NSCoding> *_Nonnull codable, BOOL requireSecureCoding, MFEncoding outputArchiveFormat) NS_REFINED_FOR_SWIFT;
id<NSCoding> _Nullable MFDecode(id _Nonnull archive, BOOL requireSecureCoding, NSSet<Class> *_Nullable expectedClasses, MFEncoding inputArchiveFormat) NS_REFINED_FOR_SWIFT;

@end
