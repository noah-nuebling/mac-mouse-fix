//
// --------------------------------------------------------------------------
// IOHIDEvent-Reconstructed.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#ifndef IOHIDEvent_Reconstructed_h
#define IOHIDEvent_Reconstructed_h

/// In the open source IOKit files, there is an IOHIDEvent.h and an IOHIDEvent.c file, but they are empty. This is my attempt at reconstructing some of its contents that we want to use

uint64_t IOHIDEventGetSenderID(IOHIDEventRef);


#endif /* IOHIDEvent_Reconstructed_h */
