//
// --------------------------------------------------------------------------
// ModifiedDragOutputZoom.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "ModifiedDrag.h"

NS_ASSUME_NONNULL_BEGIN

/// Dragging up or right zooms in, dragging down or left zooms out.
@interface ModifiedDragOutputZoom : NSObject<ModifiedDragOutputPlugin>

@end

NS_ASSUME_NONNULL_END
