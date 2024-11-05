//
// --------------------------------------------------------------------------
// MFCoding.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// All object pointers in this file are nullable.
///     Unfortunately there's only `NS_ASSUME_NONNULL` and no `NS_ASSUME_NULLABLE`.
///     Afaik, these will all be imported into Swift as implicitly unwrapped optionals. We we write a proper Swift wrapper that handles optionals correctly.

#import <Foundation/Foundation.h>

@interface MFCoding : NSObject

NSData *MFEncode(NSObject<NSCoding> *codable, BOOL requireSecureCoding, NSPropertyListFormat plistFormat) NS_REFINED_FOR_SWIFT;
NSObject<NSCoding> *MFDecode(NSData *data, BOOL requireSecureCoding, NSArray<Class> *expectedClasses) NS_REFINED_FOR_SWIFT;

@end
