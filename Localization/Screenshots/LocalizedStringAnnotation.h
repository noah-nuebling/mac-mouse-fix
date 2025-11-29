//
// --------------------------------------------------------------------------
// LocalizedStringAnnotation.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "MFSimpleDataClass.h"

mfdata_cls_h(StringAnnotation,
    NSString *key;
    NSString *table;
    NSRange  rangeInString;
)

@interface StringAnnotation (SwiftCompat)
    @property(readonly) NSString *key;
    @property(readonly) NSString *table;
    @property(readonly) NSRange   rangeInString;
@end

@interface LocalizedStringAnnotation : NSObject

    + (NSArray<StringAnnotation *> *) extractAnnotationsFromString: (NSString *)string; /// Only used by `IS_XC_TEST` [Nov 2025]
    + (NSString *) stringByAnnotatingString: (NSString *)string withKey: (NSString *)key table: (NSString *_Nullable)table;
    + (void) temporarilyDisableAutomaticAnnotation: (bool)disable;
    + (void) enableAutomaticAnnotation;

@end
