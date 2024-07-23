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

#define __DISABLE_SWIFT_BRIDGING(__type) \
    __DISABLE_SWIFT_BRIDGING_BASE(__type, id)

#if defined(__swift__)
#define __DISABLE_SWIFT_BRIDGING_BASE(__realType, __unbridgedBaseType) __unbridgedBaseType
#else
#define __DISABLE_SWIFT_BRIDGING_BASE(__realType, __unbridgedBaseType) __realType
#endif

#endif /* DisableSwiftBridging_h */
