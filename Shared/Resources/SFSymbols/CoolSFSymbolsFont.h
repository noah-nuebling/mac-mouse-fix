//
// --------------------------------------------------------------------------
// CoolSFSymbolsFont.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CoolSFSymbolsFont : NSObject

+ (BOOL)symbolCharacterIsDisplayable:(NSString *)characterString;

+ (void)uninstallFont;
+ (void)installFont;

@end

NS_ASSUME_NONNULL_END
