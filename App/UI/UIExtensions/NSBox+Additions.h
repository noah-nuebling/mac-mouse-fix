//
// --------------------------------------------------------------------------
// NSBox+Additions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Cocoa/Cocoa.h>

@interface NSBox (PrivateStuff)
    - (void) _directlyAddSubview:(NSView *_Nonnull)arg1 positioned:(NSWindowOrderingMode)arg2 relativeTo:(NSView *_Nullable)arg3; /// [Aug 2025] Extracted on Tahoe Beta 8. [addSubview:] is overriden to add into the NSBox's contentView instead.
@end
