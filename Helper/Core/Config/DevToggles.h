//
// --------------------------------------------------------------------------
// DevToggles.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

/// Note: [Jun 2025] These variables purposefully have generic names so they can be used in different context.

#define MF_TEST 0

#if MF_TEST /// Don't use these in prod builds!

    extern double devToggles_C;
    extern int    devToggles_Lo;
    extern int    devToggles_Hi;
    
#endif
