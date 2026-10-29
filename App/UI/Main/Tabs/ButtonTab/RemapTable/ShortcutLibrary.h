//
// --------------------------------------------------------------------------
// ShortcutLibrary.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Built-in keyboard shortcuts of common apps. They appear at the top of the effect menu of that app's rows.
/// Only entries with a source are in the library. Each entry was checked against the vendor's documentation (2026-10-25).
@interface ShortcutLibrary : NSObject

/// Effect-menu entries for the app, in the same format as the one-shot effects table (`ui`, `tool`, `dict`).
/// Empty if the app has no entries.
+ (NSArray *)effectsMenuEntriesForBundleID:(NSString *)bundleID;

@end

NS_ASSUME_NONNULL_END
