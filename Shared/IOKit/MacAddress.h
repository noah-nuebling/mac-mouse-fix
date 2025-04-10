//
// --------------------------------------------------------------------------
// MacAddress.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#ifndef MacAddress_h
#define MacAddress_h

#import <Foundation/Foundation.h>

NSData *_Nullable get_mac_address(void);

uint64 mac_address_to_int(NSData *_Nullable mac_address_data);
NSString *_Nullable mac_address_to_string(NSData *_Nullable mac_address_data);

#endif /* MacAddress_h */
