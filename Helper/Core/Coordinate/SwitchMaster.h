//
// --------------------------------------------------------------------------
// SwitchMaster.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#pragma once

#import <Foundation/Foundation.h>

@class ScrollConfig;

void SwitchMaster_Load_Manual(void);
void SwitchMaster_LockDown(void);
void SwitchMaster_HelperStateChanged(void);
void SwitchMaster_GeneralConfigChanged(NSDictionary *generalConfig);
void SwitchMaster_AttachedDevicesChanged(NSArray *devices);
void SwitchMaster_RemapsChanged(NSDictionary *remaps);
void SwitchMaster_ScrollConfigChanged(ScrollConfig *scrollConfig);
void SwitchMaster_ModifiersChanged(NSDictionary *modifiers);
