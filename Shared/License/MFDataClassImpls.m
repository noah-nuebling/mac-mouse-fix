//
// --------------------------------------------------------------------------
// MFDataClassImpls.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

///
/// `MFDataClass` classes can be fully defined in the header, or in the implementation.
///  But if we define them in the header, we need to create an empty implementation to please the compiler.
///
///  -> **This file is a place where we can put all those compiler-pleasing MFDataClass implementations**, that don't have a better place elsewhere.
///
/// Sidenote:
///     We need to import all the headers where the `MFDataClassInterface()` definitions live for the `MFDataClassImplementation()` macros to work.

#define DoGenerateMFDataClassImplementations 1
#import "MFDataClass.h"
#undef DoGenerateMFDataClassImplementations

/// License.h
#import "License.h"
