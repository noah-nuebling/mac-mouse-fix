//
// --------------------------------------------------------------------------
// NSMenu+NSMenu_Additions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSMenu (NSMenu_Additions)

    /// Retrieve items by identifier
    - (NSMenuItem * _Nullable)itemWithIdentifier:(NSUserInterfaceItemIdentifier)identifier;

@end

@interface NSPopUpButton (NSMenu_Additions)

    /// Retrieve items by identifier
    - (NSMenuItem * _Nullable)itemWithIdentifier:(NSUserInterfaceItemIdentifier)identifier;
    - (void)selectItemWithIdentifier:(NSUserInterfaceItemIdentifier)identifier;

@end

NS_ASSUME_NONNULL_END
