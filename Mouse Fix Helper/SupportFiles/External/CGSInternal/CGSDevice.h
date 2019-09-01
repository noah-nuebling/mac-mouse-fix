//
//  CGSDevice.h
//  CGSInternal
//
//  Created by Robert Widmann on 9/14/13.
//  Copyright (c) 2016 CodaFi. All rights reserved.
//  Released under the MIT license.
//


#ifndef CGS_DEVICE_INTERNAL_H
#define CGS_DEVICE_INTERNAL_H

#include "CGSConnection.h"

/// Actuates the Taptic Engine underneath the user's fingers.
///
/// Valid patterns are in the range 0x1-0x6 and 0xf-0x10 inclusive.
///
/// Currently, deviceID and strength must be 0 as non-zero configurations are not
/// yet supported
CG_EXTERN CGError CGSActuateDeviceWithPattern(CGSConnectionID cid, int deviceID, int pattern, int strength) AVAILABLE_MAC_OS_X_VERSION_10_11_AND_LATER;

/// Overrides the current pressure configuration with the given configuration.
CG_EXTERN CGError CGSSetPressureConfigurationOverride(CGSConnectionID cid, int deviceID, void *config) AVAILABLE_MAC_OS_X_VERSION_10_10_3_AND_LATER;

#endif /* CGSDevice_h */
