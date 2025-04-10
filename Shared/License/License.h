//
// --------------------------------------------------------------------------
// Licensing.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Most Licensing code is in Swift. 
///     Use this file only for stuff that's not possible in Swift, like creating MFDataClasses, enums or structs that are usable from both objc and swift

#ifndef License_h
#define License_h

#import "MFDataClass.h"

/// MARK: Enums
///     Note: Using simple consts instead of actual C enums because Swift is annoying about those.
///             How is it annoying? For example, you cannot simply cast integers to enums in Swift using `as?` - that always fails. Instead you have to use `init(rawValue:)` to create a special 'enum case struct instance' or something.
///             However, those initializers *never* fail even if you pass in values outside the enum range. So this serves no discernable purpose except being confusing.
///             What's extra confusing: If you declare the enums using `NS_ENUM`, or `NS_CLOSED_ENUM` in C, then`init(rawValue:)` in Swift will have have an optional return type (indicating that it's failable) but it will never actually fail. Which is extraaa confusing. (Tested this Oct 2024)
///             -> Because of these drawbacks, we just define a set of constants, instead of an actual enum. That way the behavior in Swift should be simple and consistent and match C.

typedef NSInteger MFValueFreshness;
    static const MFValueFreshness kMFValueFreshnessNone     = 0;  // TODO: Rename to `Unknown` for consistency with other enums (?)
    static const MFValueFreshness kMFValueFreshnessFresh    = 1;  // Value comes straight from the source-of-truth                (likely a server on the internet)
    static const MFValueFreshness kMFValueFreshnessCached   = 2;  // Value comes from a cache                                     (likely because the source of truth is not accessible)
    static const MFValueFreshness kMFValueFreshnessFallback = 3;  // Value comes from a list of fallback values                   (likely because neither the server nor the cache are accessible)
            
/// MARK: Dataclasses

/// Define licenseTypeInfo classes
///     There are different types of licenses.
///         Each of the `MFLicenseTypeInfo` subclasses identifies a license type.
///         Additionaly, the `MFLicenseTypeInfo` instance properties may hold *additional metadata* relevant for the license type.
///
///     This 'metadata' could be useful to adjust the app's behaviour. For example:
///         - Showing a special thank-you message or other easter eggs for people who bought the 'generous' or 'very generous' tiers of a standard license.
///         - Showing the name of the HyperWork mouse that came with the currently active MMF license
///         - For a subscription-based business license:
///             - Saving the expiration date of the subscription, so that we can check-in with the licenseServer upon license expiration (And before expiration, we would do offline validation)
///             - Saving the business name, so we can show "Licensed to business: SpaceX" or something like that on the About tab.
///
///     Sidenote on *Metadata Particles*:
///         There might be repeated metadata fields between the different `MFLicenseTypeInfo` classes.
///         We were thinking of introducing an extra level of abstraction, where we group the metadata fields into collections called 'MetadataParticles'
///         which can be reused between licenseTypes. E.g. There'd be a `MFLicenseTypeInfoParticleSeats` particle which is present in the metadata for every licenseType that has multiple seats. It might contain the fields `usedUpSeats` and `nOfSeats` or something like that.
///         However, I decided that this extra abstraction layer is kinda unnecessary and overcomplicates things. Instead, we can just use keyValueCoding to access the repeated metadata fields across the different metadata classes in a uniform way.
///         For example we might use `[license.metadata valueForKey:@"nOfSeats"]` to get the `nOfSeats` regardless of which exact `MFLicenseTypeInfo` class is being used.
///

/// licenseTypeInfo dataclasses

MFDataClassInterface0(MFDataClassBase, MFLicenseTypeInfo)                               /// The empty base-class. Tip: Make sure to never instantiate this (e.g. from an archive) since our code doesn't expect that.
    
    MFDataClassInterface0(MFLicenseTypeInfo, MFLicenseTypeInfoNotLicensed)
    
    /// Special conditions
    MFDataClassInterface1(MFLicenseTypeInfo, MFLicenseTypeInfoFreeCountry,               /// Licensed since it's used in country like China or Russia where you can't pay for the app
                          readonly, strong, nonnull, NSString *, regionCode)
    MFDataClassInterface0(MFLicenseTypeInfo, MFLicenseTypeInfoForce)                     /// Licensed due to `FORCE_LICENSED` compilation flag
    
    /// Standard licenses
    MFDataClassInterface0(MFLicenseTypeInfo, MFLicenseTypeInfoGumroadV0)                /// Old Euro-based licenses that were sold on Gumroad during the MMF 3 Beta.
    MFDataClassInterface0(MFLicenseTypeInfo, MFLicenseTypeInfoGumroadV1)                /// Standard USD-based Gumroad licenses that were sold on Gumroad after MMF 3 Beta 6 (IIRC).
    
    #if 0
        MFDataClassInterface0(MFLicenseTypeInfo, MFLicenseTypeInfoPaddleV1)                 /// Standard MMF 3 licenses that we plan to sell on Paddle, verified through our AWS API. (This is the plan as of [Oct 2024])
                                                                                            ///     Update: [Apr 2025] We plan to sell through Stripe directly now. It has much nicer UX for purchasers. More polished. Not using a merchant of record is not as much of a problem as I thought according to some internet article I read (Because Freibeträge are so high that I'd be very rich before any country would go after me for sales taxes, at which point I could afford a tax department, lol) Mr. Kuschling agreed. I also saw some other indie app using Stripe directly (I forgot which one.)
    #endif
    
    /// Special licenses
    #if 0
        MFDataClassInterface1(MFLicenseTypeInfo, MFLicenseTypeInfoHyperWorkV1,              /// Licenses issued by HyperWork mouse company and verified through our AWS API.
                            readonly, strong, nonnull, NSString *, deviceSerialNumber)
        MFDataClassInterface0(MFLicenseTypeInfo, MFLicenseTypeInfoGumroadBusinessV1)        /// Perhaps we could introduce a license type for businesses. You could buy multiple/multiseat licenses, and perhaps it would be more expensive / subscription based?. (Sidenote: This licenseType includes `V1`, but not sure that makes sense. The only practical application for 'versioning' the licenseTypes like that I can think of is for paid upgrades, but that doesn't make sense for a subscription-based license I think, but I guess versioning doesn't hurt)
    #endif

    /// V2 licenses:
    ///     Explanation:
    ///     If we ever want to introduce a paid update we could add new V2 licenses
    ///     and then make the old V1 licenses incompatible with the newest version of Mac Mouse Fix.
    #if 0
        MFDataClassInterface0(MFLicenseTypeInfo, MFLicenseTypeInfoGumroadV2)
        MFDataClassInterface0(MFLicenseTypeInfo, MFLicenseTypeInfoPaddleV2)
    #endif

/// Top-level dataclasses

MFDataClassInterface3(MFDataClassBase, MFLicenseState,   readonly, assign,        , BOOL,                          isLicensed,
                                                         readonly, assign,        , MFValueFreshness,              freshness,
                                                         readonly, strong, nonnull, MFLicenseTypeInfo *,           licenseTypeInfo)

MFDataClassInterface4(MFDataClassBase, MFTrialState,     readonly, assign,        , NSInteger,  daysOfUse,
                                                         readonly, assign,        , NSInteger,  daysOfUseUI,
                                                         readonly, assign,        , NSInteger,  trialDays,
                                                         readonly, assign,        , BOOL,       trialIsActive)
    
/// Note: MFLicenseConfig abstracts away licensing params like the trialDuration or the price. At the time of writing (Oct 2024) the configuration is loaded from macmousefix.com. This allows us to easily change parameters like the price displayed in the app for all users.
MFDataClassInterface10(MFDataClassBase, MFLicenseConfig,    readonly, assign,        , MFValueFreshness     , freshness,
                                                            readonly, assign,        , NSInteger            , maxActivations,
                                                            /// ^^ Define max activations
                                                            ///     I want people to activate MMF on as many of their machines  as they'd like.
                                                            ///     This is just so you can't just share one licenseKey on some forum and have everyone use that forever. This is probably totally unnecessary.
                                                            readonly, assign,        , NSInteger            , trialDays,
                                                            readonly, assign,        , NSInteger            , price,
                                                            readonly, strong, nonnull, NSString *           , payLink,
                                                            readonly, strong, nonnull, NSString *           , quickPayLink,
                                                            readonly, strong, nonnull, NSString *           , altPayLink,
                                                            readonly, strong, nonnull, NSString *           , altQuickPayLink,
                                                            readonly, strong, nonnull, NSArray<NSString *> *, altPayLinkCountries,
                                                            readonly, strong, nonnull, NSArray<NSString *> *, freeCountries)
                                                            /// ^^ The altPayLink, altQuickPayLink, and altPayLinkCountries params are meant to be used to provide an alternative payment method for users in China and Russia where Gumroad doesn't work properly at the moment. They are unused at the time of writing. The freeCountries parameter lists countries in which the app should be free. This is meant as a temporary solution until we implemented the alternative payment methods.

/// MARK: Dataclass extensions
///     Explanations in the .m file

@interface MFLicenseTypeInfo (Extensions)
    BOOL MFLicenseTypeIsPersonallyPurchased(MFLicenseTypeInfo *_Nullable info);
    BOOL MFLicenseTypeRequiresValidLicenseKey(MFLicenseTypeInfo *_Nullable info);
@end

@interface MFLicenseConfig (Extensions)
    NSString *_Nonnull MFLicenseConfigFormattedPrice(MFLicenseConfig *_Nonnull config);
    - (instancetype _Nullable)initWithJSONDictionary:(NSMutableDictionary *_Nonnull)dict freshness:(MFValueFreshness)freshness requireSecureCoding:(BOOL)requireSecureCoding;
@end

/// MARK: Custom errors
///     Notes:
///     - Most of these are thrown in Gumroad.swift, but `kMFLicenseErrorCodeNoInternetAndNoCache` and `kMFLicenseErrorCodeEmailAndKeyNotFound` are thrown in Licensing.swift.
///     - Overall these should cover everything that can go wrong. With the `kMFLicenseErrorCodeGumroadServerResponseError` catching all the weird edge cases like a refunded license.
///     - The `kMFLicenseErrorCodeGumroadServerResponseError` also catches the case when a user just enters a wrong license.
///     - These could be used to inform the user about what's wrong.
///
///     General:
///         - We should probably clean up our use of NSErrorDomain (+ errorCodes +  NSExceptionName)
///             -> There's only one NSCocoaErrorDomain. So there should probably only one `MFErr` error domain.
///             -> We also use 12345689 or -1 or whatever as the error codes in several places. We should probably at least introduce `kMFErrorCodeUnspecified` to clean that stuff up.
///             -> (Since we're not writing a library and not displaying user feedback for 95% of the errors, we don't need specific error codes because we don't implement any handling logic - it's just for debugging purposes.) (But then on the other hand, why not just log the errors directly instead of throwing them if they are just for debugging purposes?)
///             -> Maybe we should also introduce a single `NSExceptionName`:`kMFExceptionNameUnspecified`

static const NSErrorDomain _Nonnull MFLicenseErrorDomain = @"MFLicenseErrorDomain";
typedef NSInteger MFLicenseErrorCode;
    //const MFLicenseErrorCode kMFLicenseErrorCodeMismatchedEmails               = 1;       /// Not using emails for authentication anymore. Just licenseKeys
    static const MFLicenseErrorCode kMFLicenseErrorCodeInvalidNumberOfActivations   = 2;    /// The license is valid as per the server but it has been activated a suspicious number of times.
    static const MFLicenseErrorCode kMFLicenseErrorCodeGumroadServerResponseError   = 3;    /// The Gumroad server has responded with `success: false`
    static const MFLicenseErrorCode kMFLicenseErrorCodeServerResponseInvalid        = 4;    /// The server response does not follow the expected format.
//    static const MFLicenseErrorCode kMFLicenseErrorCodeKeyNotFound                  = 5;
//    static const MFLicenseErrorCode kMFLicenseErrorCodeNoInternetAndNoCache         = 6;    /// Oct 2024: Should rename this to noServerAndNoCache - since there are other reasons that we might not get a clear response from the server about whether a license is valid or not

static const NSErrorDomain _Nonnull MFLicenseConfigErrorDomain = @"MFLicenseConfigErrorDomain";
typedef NSInteger MFLicenseConfigErrorCode;
    static const MFLicenseConfigErrorCode kMFLicenseConfigErrorCodeInvalidDict = 1;

#endif /* License_h */

/**
    Other ideas for structs and unions we could use to represent the `MFLicenseAndTrialState`:
        (We should probably delete this at some point)
 
        ```
         union MFLicenseMetadataaa {
             
             /// Each licenseType could have a different set of `metadata` that the app can use to adjust its behaviour
             ///    For example:
             ///    - Showing the name of the HyperWork mouse that came with the currently active MMF license
             ///    - Saving the expiration date of a subscription-based business license, so that we can verify the license with the licenseServer upon expiration (Instead of doing offline verification of the license.)
             ///    - Showing a special thank-you message or other easter eggs for people who bought the 'generous' or 'very generous' tiers of a standard license.

             /// Standard licenses
             struct { /// Metadata for licenses of type `kMFLicenseTypeMMF3GumroadOldEuro`
                 NSInteger option;   /// 1, 2 or 3 --- 1 -> standard option, 2 -> 'generous' supporter, 3 -> 'very generous' supporter
             } MMF3GumroadOldEuro;
             struct {
                 NSInteger option;
             } MMF3Gumroad;
             struct {
                 NSInteger option;
             } MMFPaddle;
             
             /// Special licenses
             struct { /// Metadata for licenses of type `MMF3HyperWork`
                 NSString *deviceName;       /// Name of the HyperWork device which shipped with the activated MMF license
                 NSString *devicePurchaseDate;
             } MMF3HyperWork;
             
             struct {
                 NSInteger seat;
                 NSInteger nOfSeats;
                 NSString *licenseOwner;
                 NSDate *subscriptionPaidForUntil;
             } MMF3Business;
         };
                
        /// Perhaps, instead of having different licenseTypes, we could model the information associated with the licenseTypes more granularly? Kinda like this:
        ///         Note: This idea became the 'Metadata Particles' idea.

        typedef enum {
            kMFLicenseIssuerPaddle,
            kMFLicenseIssuerGumroad,
            kMFLicenseIssuerHyperWork,
        } MFLicenseIssuer;

        typedef enum {
            kMFLicenseVerifierAWS,      /// Paddle and HyperWork licenses are verified through our AWS API
            kMFLicenseVerifierGumroad,  /// Gumroad licenses are verified through the Gumroad API.
        } MFLicenseVerifier;
        ```
 
    Metadata particle implementation idea (As **MFDataClasses**):
 
        ```
         /// NOTEPAD: (Exploring how we might use these datastructures:)
         ///  ```
         ///  for metadataParticle in licenseAndTrialState.license.metadata.allPropertyValues {
         ///         if let particle = metadataParticle as? MFMetaDataParticleSupportedLevel {
         ///         if (particle.supporterLevel.intValue == 3) {
         ///
         ///         }
         ///  ```
         ///
         /// ```
         /// if (type == kMFLicenseTypeMMF3GumroadOldEuro) {
         ///     MFLicenseMetadataMMF3GumroadOldEuro *metadata = [MFLicenseMetadataMMF3GumroadOldEuro new];
         ///     metadata.supporterLevel = @(serverReponse["supportedLevel"]);
         ///     license.metadata = metadata;
         /// }
         /// ```
         ///


         // Define metadata particles

         MFDataClassInterface(MFLicenseMetadataParticle, ())
         
         MFDataClassInterfaceSub(MFLicenseMetadataParticle, MFLicenseMetadataParticleSupporterLevel,    (MFDataProp(NSNumber *supporterLevel)))
         
         MFDataClassInterfaceSub(MFLicenseMetadataParticle, MFLicenseMetadataParticleSeats,             (MFDataProp(NSNumber *seat)
                                                                                                      MFDataProp(NSNumber *nOfSeats)))
         
         MFDataClassInterfaceSub(MFLicenseMetadataParticle, MFLicenseMetadataParticleSubscription,      (MFDataProp(NSDate *subscriptionIsPaidForUntil)))
         
         MFDataClassInterfaceSub(MFLicenseMetadataParticle, MFLicenseMetadataParticleBusiness,          (MFDataProp(NSString *licenseOwner)))
         
         MFDataClassInterfaceSub(MFLicenseMetadataParticle, MFLicenseMetadataParticleHyperWork,         (MFDataProp(NSString *deviceName)
        ```
        
    Metadata  & particles implementation idea (As union of structs):
        ```
        /// NOTEPAD: (Exploring how we might use these datastructures:)
        ///
        ///  for i in range(sizeof(MFLicenseMetadata) / sizeof(MFLicenseMetaDataParticle)) {
        ///      union MFLicenseMetaDataParticle particle = licenseAndTrialState.license.metadata[i]
        ///
        ///                 if (particle.particleID == kMFMetadataParticleIDSupporterLevel)
        ///
        ///                 } else if ()
        ///
        ///  }

        /// Define metadata particles

        struct MFLicenseMetaDataParticle {
            
            enum MFMetadataParticleID {
                
                kMFMetadataParticleIDNone,
                kMFMetadataParticleIDSupporterLevel,
                kMFMetadataParticleIDSeats,
                kMFMetadataParticleIDSubscription,
                kMFMetadataParticleIDHyperWork,
                
            } particleID;
            
            union { /// union of structs of metadataParticles
                struct {
                    enum MFSupporterLevel {
                        kMFSupporterLevelBase,
                        kMFSupporterLevelGenerous,
                        kMFSupporterLevelVeryGenerous,
                    } level;
                } SupporterLevel;
                
                struct {
                    NSInteger seat;
                    NSInteger nOfSeats;
                } Seats;
                
                struct {
                    NSDate *subscriptionPaidForUntil;
                } Subscription;
                
                struct {
                    NSString *deviceName; /// Name of the HyperWork device which shipped with the activated MMF license
                    NSDate *devicePurchaseDate;
                } HyperWork;
            } data;
        };

        struct MFLicenseMetaDataParticles {
            
            struct {
                bool metadataIsPresent;
                enum {
                    base,
                    generous,
                    veryGenerous,
                } level;
            } SupporterLevel;
            
            struct {
                bool metadataIsPresent;
                NSInteger seat;
                NSInteger nOfSeats;
            } Seats;
            
            struct {
                bool metadataIsPresent;
                NSDate *subscriptionPaidForUntil;
            } Subscription;
            
            struct {
                bool metadataIsPresent;
                NSString *deviceName; /// Name of the HyperWork device which shipped with the activated MMF license
                NSDate *devicePurchaseDate;
            } HyperWork;
        };

 
         struct MFLicenseMetadata  {
         
             /// The licenseState has a `metadata` field which contains data that is only present for specific licenseTypes.
             ///    This data could be useful to adjust the app's behaviour.
             ///    For example:
             ///    - Showing the name of the HyperWork mouse that came with the currently active MMF license
             ///    - Saving the expiration date of a subscription-based business license, so that we can verify the license with the licenseServer upon expiration (Instead of doing offline verification of the license.)
             ///    - Showing a special thank-you message or other easter eggs for people who bought the 'generous' or 'very generous' tiers of a standard license.
         
             enum MFLicenseType {
         
                 kMFLicenseTypeUnknown,
         
                 /// Standard licenses
                 kMFLicenseTypeMMF3GumroadOldEuro,  /// Old Euro-based licenses that were sold on Gumroad during the MMF 3 Beta.
                 kMFLicenseTypeMMF3Gumroad,         /// Standard Gumroad licenses that were sold on Gumroad after MMF 3 Beta 6 (IIRC).
                 kMFLicenseTypeMMF3Paddle,          /// Standard MMF 3 licenses sold on Paddle, verified through our AWS API.
         
                 /// Special licenses
                 kMFLicenseTypeMMF3HyperWork,                /// Licenses issued by HyperWork mouse company and verified through our AWS API.
                 kMFLicenseTypeMMF3Business,                 /// Perhaps we could introduce a license type for businesses. You could buy multiple/multiseat licenses, and perhaps it would be more expensive / subscription based?
         
                 /// If we ever want to introduce a paid update we could add new license types like this:
             //    kMFLicenseTypeMMF5Gumroad,
             //    kMFLicenseTypeMMF5Paddle,
         
             } licenseType;
         
             union { /// union of structs of license-type-specific metadata
                 /// Standard licenses
                 struct {
                     struct MFLicenseMetaDataParticle supporterLevel;
                 } MMF3GumroadOldEuro;
                 struct {
                     struct MFLicenseMetaDataParticle supporterLevel;
                 } MMF3Gumroad;
                 struct {
                     struct MFLicenseMetaDataParticle supporterLevel;
                 } MMF3Paddle;
         
                 /// Special licenses
                 struct {
                     struct MFLicenseMetaDataParticle hyperWork;
                 } MMF3HyperWork;
                 struct {
                     struct MFLicenseMetaDataParticle subscription;
                     struct MFLicenseMetaDataParticle seats;
                 } MMF3Business;
         
                 struct MFLicenseMetaDataParticle particleArray[2]; /// ! Keep in sync with largest struct in the union.
             } data;
         };

        ```
 
        Original struct definintions of the top-level dataclasses
            -> We moved to dataclasses because, as soon as you put an object into these structs, they can't be imported into Swift anymore, so we made everythin an object using our `MFDataClass`es
        ```
         typedef struct {
             bool isLicensed;
             MFValueFreshness freshness;
             MFLicenseReason licenseReason;
             MFLicenseType licenseType;
             MFLicenseMetadata *metadata;
         } MFLicenseState;

         typedef struct {
             NSInteger daysOfUse;
             NSInteger daysOfUseUI;
             NSInteger trialDays;
             bool trialIsActive;
         } MFTrialState;

         typedef struct MFLicenseAndTrialState {
             MFLicenseState license;
             MFTrialState trial;
         } MFLicenseAndTrialState;
        ```
 
 */
