//
// --------------------------------------------------------------------------
// DisableSwiftBridging.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#ifndef DisableSwiftBridging_h
#define DisableSwiftBridging_h

/// Define type-eraser macros

#define MF_SWIFT_UNBRIDGED(__type) \
    MF_SWIFT_UNBRIDGED_BASE(__type, id)

#if defined(__swift__)
#define MF_SWIFT_UNBRIDGED_BASE(__realType, __nonBridgedBaseType) __nonBridgedBaseType
#else
#define MF_SWIFT_UNBRIDGED_BASE(__realType, __nonBridgedBaseType) __realType
#endif

#endif /* DisableSwiftBridging_h */
