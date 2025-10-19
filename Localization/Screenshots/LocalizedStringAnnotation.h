//
// --------------------------------------------------------------------------
// LocalizedStringAnnotation.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// [Oct 2025] Some of the functionality of this has moved into MFLoclizedString. Should probably move it all there and remove this.

#import <Foundation/Foundation.h>

@interface LocalizedStringAnnotation : NSObject

+ (NSString *) annotateString: (NSString *)string withKey: (NSString *)key table: (NSString *_Nullable)table;
id nsLocalizedStringBySwappingOutUnderlyingString(id nsLocalizedString, NSString *underlyingString);

@end
