//
// --------------------------------------------------------------------------
// MFDataClassDictionaryDecoder.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

@interface MFDataClassDictionaryDecoder : NSCoder
- (instancetype)initForReadingFromDict:(NSDictionary *)dict requiresSecureCoding:(BOOL)requiresSecureCoding;
- (NSDictionary *)underlyingDict;
@end
