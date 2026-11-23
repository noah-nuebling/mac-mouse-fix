//
// --------------------------------------------------------------------------
// SwitchMaster.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#pragma once

#import <Foundation/Foundation.h>
#import "DisableSwiftBridging.h"

@class ScrollConfig; /// Forward decl, because this is a Swift type and leads to weird compiler errors if we import Swift [Oct 2026]

void SwitchMaster_Load_Manual(void);
void SwitchMaster_LockDown(void);
void SwitchMaster_HelperStateChanged(void);
void SwitchMaster_GeneralConfigChanged(MF_SWIFT_UNBRIDGED(NSDictionary *) generalConfig) NS_REFINED_FOR_SWIFT;
void SwitchMaster_AttachedDevicesChanged(MF_SWIFT_UNBRIDGED(NSArray *)devices)           NS_REFINED_FOR_SWIFT;
void SwitchMaster_RemapsChanged(MF_SWIFT_UNBRIDGED(NSDictionary *)remaps)                NS_REFINED_FOR_SWIFT;
void SwitchMaster_ScrollConfigChanged(ScrollConfig *scrollConfig);
void SwitchMaster_ModifiersChanged(MF_SWIFT_UNBRIDGED(NSDictionary *)modifiers)          NS_REFINED_FOR_SWIFT;
