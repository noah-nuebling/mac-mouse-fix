//
// --------------------------------------------------------------------------
// EventLoggerForBradMacros.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "SharedUtility.h"

/// This file contains macros from EventLoggerForBrad that we copy pasted over, before properly merging the EventLoggerForBrad code into MMF.
///     TODO: Merge these when copying over EventLoggerForBrad macros

/// Changes since copying this from EventLoggerForBrad:
///     Updated ifcastn and ifcastpn to properly prevent trying to set the inner variable by moving `const` to the appropriate place in the declaration.

/// [Apr 2025]
///     Merged all the changes we made here back into EventLoggerForBrad implementations and replaced impls here with `MFDELETED`.
///         (Also replaced stuff from EventLoggerForBrad in other files with `MFDELETED`)

/// scopedvar - helper macro
/// MFDELETED

/// Helper macro: bitpos(): Get the position of the bit in a one-bit-mask
/// MFDELETED

/// safeindex() - bound-checked array access with fallback value
/// MFDELETED

/// ifcast & ifcastn
/// MFDELETED


/// ------------------------------------

/// Debug-printing enum function
/// MFDELETE
