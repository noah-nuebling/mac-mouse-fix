//
// --------------------------------------------------------------------------
// Localization.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/**
    
*/

#import <Foundation/Foundation.h>

#define MFLocalizedString(key, comment) _MFLocalizedString((key))
NSString *_MFLocalizedString(NSString *key);
