//
// --------------------------------------------------------------------------
// MFDataClassImpls.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

///
/// This file is a place to put `MFDataClassImplementX(...)` macros that don't have a better place.
///     Update: We probably won't use this. Maybe we should put some info from these comments into MFDataClass.h and then delete this file.
///
/// `MFDataClassImplementX(...)` macros are a necessary evil.
///     ... Ideally, we could define an `MFDataClass` with just one macro invocation. Instead we have to use two macro invocations if we want to import an `MFDataClass` into different files:
///         1. In an .h file, we have to put an `MFDataClassInterfaceX(...)` macro (which generates an objc `@interface`)
///         2. In an .m file, we have to put an `MFDataClassImplementX(...)` macro (which generates an objc `@implementation`)
///
///   -> Afterwards we can import the .h file and use the MFDataClass across different files.
///   -> If we change one of them we have to manually update the counterpart.
///
///  If you only need the dataclass in one file, you can use the the `MFDataClassX(...)` macros, which automatically generate both an `@interface` and an `@implementation`.
///     This works only in .m files. If we use that macro in an `.h` file, we get `duplicate symbol` errors during compilation.
///
///  Deeper discussion:
///  I think the deeper issue is that the `@implementation` for a dataclass may only be encountered by the compiler *once* during compilation.
///     We can ensure this either by putting the `@implementation` inside an .m file (that's the standard way) but we could also ensure this by leaving the `@implementation` in an .h file alongside the `@interface`, but then using macros to prevent the `@implementation` from being compiled more than once.
///     (I actually tested this and it worked.)
///     We would define a *toggle* macro which we would use to wrap the `@implementation` code defined in the .h file.
///     Then we could define the macro like this to turn `@implementation` code generation *on*:
///         `#define MFDataClass_ImplementationGenerationToggle(code) code`
///     And like this to turn `@implementation` code generation *off*:
///     `   #define MFDataClass_ImplementationGenerationToggle(code)`
///     Then, inside exactly one .m file, we would turn the @implementation-code-generation *on* before `#import`ing the .h file where the togglable `@implementation` code lives.
///         (In all other .m files that import that .h file, the @implementation-code-generation needs to be turned `off`.)
///         That way, the `@implementation` is only imported into one .m file, and encountered exactly once by the compiler, solving the `duplicate symbol` errors.
///     -> The benefit of this approach is that we don't have to use the 2 separate `MFDataClassInterfaceX(...)` and `MFDataClassImplementX()` macros. Instead we can just use one `MFDataClassX()` macro to define everything in the .h file.
///         But the disadvantage is that we have to manually make sure that there's exactly one .m file that turns on the implementation-code-generation before importing the .h file. And when defining `MFDataClass`es inside an .m file we'd also have to make sure that we turn on the `@implementation` generation.
///         Overall it just feels kinda hacky and confusing, and I think it's more typing but simpler to understand to just use the two separate `MFDataClassInterfaceX(...)` and `MFDataClassImplementX()`  macros and put one in the .h and one in the .m file. It's 'duplicated code' but we can pretty easily copy-paste stuff to keep things in-sync, so it should be fine.
///
/// Sidenote:
///     We need to import all the headers where the `MFDataClassInterfaceX()` definitions live for the `MFDataClassImplementX()` macros to work.


#import "MFDataClass.h"

/// License.h implementations
///     (We moved these into `License.m`)
//#import "License.h"
//MFDataClassImplement0(MFDataClassBase, MFLicenseTypeInfo)
//MFDataClassImplement0(MFLicenseTypeInfo, MFLicenseTypeInfoGumroadV0)
//MFDataClassImplement0(MFLicenseTypeInfo, MFLicenseTypeInfoGumroadV1)
//MFDataClassImplement0(MFLicenseTypeInfo, MFLicenseTypeInfoHyperWorkV1)
//MFDataClassImplement3(MFDataClassBase, MFLicenseState,   assign, bool,               isLicensed,
//                                                              assign, MFValueFreshness,   freshness,
//                                                              assign, MFLicenseReason,    licenseReason)
//
//MFDataClassImplement4(MFDataClassBase, MFTrialState,     assign, NSInteger,  daysOfUse,
//                                                              assign, NSInteger,  daysOfUseUI,
//                                                              assign, NSInteger,  trialDays,
//                                                              assign, bool,       trialIsActive)

//MFDataClassImplement2(MFDataClassBase, MFLicenseAndTrialState, strong, MFLicenseState * _Nonnull,    license,
//                                                                    strong, MFTrialState * _Nonnull,      trial)


//MFDataClass1(MFDataClassBase, DataClassCStringTest, readonly, assign, nonnull, const char *, cstring);


//@interface GenericsTest : NSObject
//@property(readonly, retain, nonnull, nonatomic) NSDictionary<__kindof const NSObject *, NSString *> *genericArray;
//@end
