//
// --------------------------------------------------------------------------
// RemapScope.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Posted by the remap table when its rows are loaded or written, so other UI can update.
#define kMFRemapTableDidChangeNotification @"MFRemapTableDidChange"

/// The remaps array (kMFConfigKeyRemaps) holds the global rows and the per-app rows together.
/// A row belongs to the global scope if it has no `app` key, and to an app scope if its `app` key is that bundle ID.
/// These helpers split and merge the array by scope, so that editing one scope never touches the rows of another.
///
/// Pass `app == nil` for the global scope.

@interface RemapScope : NSObject

/// The app of a row, or nil if the row is global.
///     Only a non-empty string counts as an app. The helper reads rows the same way (See `Remap.reload`), so a row with an invalid `app` value is shown and applied as a global row.
+ (nullable NSString *)appForRow:(NSDictionary *)row;

/// The rows of one scope, in their original order.
+ (NSArray *)rowsForScope:(nullable NSString *)app inRemaps:(nullable NSArray *)remaps;

/// Returns `remaps` with all rows of the scope removed, and `rows` appended.
+ (NSArray *)remapsReplacingScope:(nullable NSString *)app withRows:(NSArray *)rows inRemaps:(nullable NSArray *)remaps;

@end

NS_ASSUME_NONNULL_END
