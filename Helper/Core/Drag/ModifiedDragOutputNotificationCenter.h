//
// --------------------------------------------------------------------------
// ModifiedDragOutputNotificationCenter.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "ModifiedDrag.h"

/// Drag plugin that simulates a two-finger swipe from the right edge
/// to interactively open/close Notification Centre.
@interface ModifiedDragOutputNotificationCenter : NSObject <ModifiedDragOutputPlugin>

@end
