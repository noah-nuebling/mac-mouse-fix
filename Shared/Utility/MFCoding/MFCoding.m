//
// --------------------------------------------------------------------------
// MFCoding.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

///
/// Convenience functions for encoding/decoding objects that implement the `NSCoding` protocol.
///     (This is commonly called serialization or archiving.)
///
/// This is basically a wrapper around `NSKeyedArchiver`/`NSKeyedUnarchiver` but the API for those is kinda crazy.
///     Update: [Feb 2025] Now also a wrapper for our custom `MFPlistEncoder`/`MFPlistDecoder` coders.
///
/// Swift bridging weirdness:
///         (These comments where from back when we returned errors using an `NSError **`, they are now outdated.)
///     All these functions are completely null-safe in C/ObjC meaning you can pass in null and will just get null back.
///     However, when auto-importing this into Swift, it was impossible to get the return value to be optional.
///     It seems that methods with an `NSError **error` argument will be auto-imported into Swift as `throwing` methods that return a non-optional. I guess it assumes that *unless* there's an error, the return value will never be null. But our methods don't adhere to this rule.
///     (This weird behavior only applies to Swift auto-imported ObjC *methods*. Pure c functions don't seem to get auto-imported as `throwing`, and having their nullability changed.)
///     -> To avoid this weirdness, we just decided to write our own Swift wrappers.
///     -
///     > Update:
///         We just print errors now instead of returning them so this might be unnecessary now?
///         But the Swift wrappers also allow us to turn off / revert automatic swift briding until we merge with a version of the repo that has `MF_SWIFT_UNBRIDGED` so we can do it properly.
///         TODO: Adopt `MF_SWIFT_UNBRIDGED`
///
/// On NSCoder errors & exception handling:
///     After thinking and being confused for hours about NSCoder error handling, finally, I think I understand it a bit better:
///     I think originally, the NSArchiver APIs were written for ObjC, and they only threw exceptions, they never returned errors. But Swift doesn't support throwing/catching exceptions, it only supports returning errors. (`throws` is just syntax sugar for returning an error. ObjC exceptions work like C++ exceptions internally and do crazy stuff like unwinding the stack.)
///     So, for Swift compatibility, they added new APIs that return errors to NSCoder, but they only added them for some things so now, everything is a terrible frankensteins monster of throwing exceptions and returning errors.
///
///     For *de*coding:     (Which you'd normally do using NSKeyed*Un*archiver)
///         There seem to be 3 aspects of decoding that were being transitioned from Exception-throwing to error-returning:
///         - 1. Internal error propagation: Instead of throwing exceptions inside `initWithCoder:` you can now call `failWithError:` and then return nil.
///             -> I guess this is necessary so you can write a failable`initWithCoder:` in Swift, (since it can't *throw* exceptions.)
///         - 2. "TopLevel" errors: When you wanna decode an archive, you can use the "TopLevel" APIs which will catch decoding failures and return them as an NSError - no matter if the decoding failure was propagated internally by Exception throw or by `failWithError:`
///             -> I guess this is necessary so you can handle exception-throwing decoding failures from Swift (since it can't *catch* exceptions)
///             -> The "TopLevel" APIs we talk about have "TopLevel" in their name e.g.`[NSCoder -decodeTopLevelObjectForKey:error:]`
///           3. NSKeyedUnarchiver init & data: All exception-throwing methods seem to be deprecated, instead you should now use the error-returning `-initForReadingFromData:error:` to initialize the unarchiver and pass it the data to decode.
///     For *en*coding:     (Which you'd normally do using NSKeyedArchiver)
///         - 1. Internal error propagation: All internal error propagation still seems to be exception-based, without any error-returning alternatives.
///         - 2. "TopLevel" errors: There is one convenience function that seems to convert exceptions to errors at the 'TopLevel': `+archivedDataWithRootObject:requiringSecureCoding:error:`
///             -> But absolutely no other methods return errors. It seems you can only use them safely from objc using `try-catch` Exception handling.
///
///     On NSDecodingFailurePolicy:
///         - Based on this, I have the question: Can you use exception handling for everything, or do you have to use a hybrid, frankensteins approach where you use `try-catch` for some things and returned errors for others?
///         -> I think this is what the failurePolicy option is for.
///             When you set the failurePolicy to `.raiseException`, then `failWithError:` invocations will cause an exception to be thrown, and therefore, you can handle everything via a `try-catch` block at the top level.
///             When you set the failurePolicy to `.setErrorAndReturn`, then this automatic conversion from [errors passed into `failWithError:`[ to [exceptions] is turned off.
///                 Then you're required you to use a 'frankensteins approach' at the topLevel where you handle *en*coding errors via returned errors, and *de*coding via `try-catch`.
///                 Also, the Apple docs suggest that this would break if any exceptions are thrown while decoding, probably bc exception-catching at the topLevel is turned off entirely when `.setErrorAndReturn` is used and it expects all initWithCoder: implementations to always use `failWithError:` instead of throwing an exception.
///                 So it's inconsistent and less robust compared to using `.raiseException`
///                 The thing is, `.raiseExceptions` is perfectly usable in any context. Even if you're using Swift and you need returned errors bc you can't catch errors, you can still use the "TopLevel" APIs to catch and convert the internally thrown exceptions to errors at the top-level.
///                 The only benefit of the `.setErrorAndReturn` policy - I suppose - is efficiency.
///                 If you do everything with returned errors, meaning that:
///                     - 1. You propagate all your errors internally via returned errors
///                     - 2. You handle all things at the topLevel via returned errors.
///                     Then the steps introduced by the`.raiseExceptions` policy are a waste of computing resources, because for any decoding failure, you would:
///                     - 1. Convert the error passed into`failWithError:` to an exception and throw it
///                     - 2. Catch the exception at the topLevel and then convert it *back* to an NSError, and return it.
///
///     On `NSCoder.error`:
///         I think the `NSCoder.error` property is used internally to propagate an error to the topLevel. We should ignore it. I'm not sure why it's a not private property.
///         NSCoder.error is set by `failWithError:` and then read and returned by the "TopLevel" APIs such as`decodeTopLevelObjectAndReturnError:` (That is, unless the failurePolicy is `.raiseException`, in which case the error will be propagated to the topLevel by exception-throwing instead of through the `NSCoder.error` property.)
///         Weird thing: the docs also say `.error` is "An error in the top-level *en*code", but all the other doc text about `.error` only speaks about *de*coding, so maybe "encode" here this is a typo in the docs, or maybe I"m missing something?
///
///     Other:
///         I'm wondering - how do the NSKeyedArchiver API convert NSException to NSError? Can/should we reuse that mechanism? For now we're just logging the exceptions but if we ever want to handle them it might be nice to reuse that conversion mechanism.
///
/// On validation of decoded values:
///     On **NSSecureCoding**: (Last updated: [Feb 2025]) (This discussion used to be at `MFDataClass.m > initWithCoding:`)
///         The **core problem** that NSSecureCoding tries to address, is basically that there's a possibility that, between encoding and decoding an object, the encoded data could be manipulated by attackers in malicious ways. (serialization attack)
///             > To prevent the hackers from realizing their mischievous plans, you can **validate** the decoded data.
///             > This can only happen for **untrusted sources** of data. When your encoded data comes from a **trusted source**, (like the user's library, as is the case for config.plist in Mac Mouse Fix), then its not feasable for any hacker to manipulate the archived data before we load it.
///         I thought about this a bit and I think NSSecureCoding and how Apple communicates it is a bit weird / ineffective.
///         The `NSSecureCoding` documentation only speaks about validating that the decoded objects' *classes* are what you expect.
///             This, however, is not enough to prevent malicious tampering. For example if you decode a URL, that could be replaced by a hacker with a phishing URL. And even if you implement `NSSecureCoding` exactly as advertised by Apple, that wouldn't help at all.
///             For some reason Apple only focuses on class-substitution attacks with `NSSecureCoding`.
///                 There is one thing that's special about class-substitution-attacks which warrants implementing a special API, but doesn't seem to warrant focusing the entire `NSSecureCoding` protocol around it and pushing everyone to adopt it:
///                     The thing that's special is that: For all other types of validation except for matching-class-validation, you can make the decoding watertight against attackers by validating the decoded values *after* they come out of the decoder.
///                     But when decoding objects, their -init or +load methods could already produce side-effects before you can validate whether the object is of the right class.
///                     -> So this opens a possible attack vector, (which would be very hard to do anything useful with since the hacker could still only instantiate classes which are already loaded, and could only work with their -initWithCoder, +initialize or +load methods.)
///                         This attack-vector cannot be closed by traditional validation methods where you validate the class *after* it comes out of the decoder, so that's why `-[NSCoder decodeObjectOfClass:]` exists. It makes sense.
///         -> So I understand why `decodeObjectOfClass:` exists - it makes it possible to make your decoding process *totally* watertight against attackers, *if* you use it alongside more extensive validation.
///         -> But the only thing that `NSSecureCoding` does is tell/require you to use `decodeObjectOfClass:`. And Apple seems to basically push everybody to use `NSSecureCoding` all the time.
///             This doesn't make sense to me because:
///             If you have a **trusted source** for the data, -decodeObjectOfClass: / NSSecureCoding is basically entirely unnecessary. (Explained below)
///             If you have an **untrusted source**, just adopting -decodeObjectOfClass:/NSSecureCoding is by far not enough validation to make things really watertight against attacks, but Apple doesn't seem to mention this in the `NSSecureCoding` docs.
///
///         Should we ever validate decoded values from archives from **trusted sources**?
///                 (Short answer: No.)
///             For trusted sources, no hacker can manipulate the encoded data. Let's think about whether there are there other reasons to validate the values that come out of the decoder:
///                 1. Data corruption? - No.
///                     Accidental data corruption would result in an invalid archive with extremely high likelyhood, so if you successfully unarchived your entire object graph, validating invariants on the decoded values is unnecessary.
///                 2. Data-layout changes between program versions? - No.
///                     If, in a new version of your program, the layout of a datastructure changes, such that previously-valid values violate new invariants, then you could theoretically use high-level validation to detect these
///                         invariant-violations, and reject/repair the archive.
///                     However, to do this in a water-tight way, you'd have to exactly describe all of the invariants which I think would be *very* cumbersome and error prone.
///                     Instead, you should use **versioning** for your data structures.
///                         Then you can detect "Ah, the archive contains v3, but we need v4, so we'll apply our repair routine that knows exactly how to upgrade from v3 to v4"
///                         Sidenote: In MMF, we currently [Feb 2025] version and 'upgrade' our entire config.plist, which solves this problem across the entire app (I think)
///                                 > If we receive archives of datastructures from a source other than the config.plist, we might need to add an additional versioning mechanism there.
///
///     Reasons to use **validation** in MMF:
///         As explained in `On **NSSecureCoding**` above, validation is mostly unnecessary, unless we're decoding data from an untrusted source,
///             in which case we should add **custom validations** to make things *actually* secure.
///
///         -> Brainstorm: Are untrusted data sources a concern for Mac Mouse Fix?
///             - Anyone can send data to our message ports. [Feb 2025] ... But the best solution is probably to lock down the message port, so received messages are 'trustworthy'.
///             - If we promote sharing config.plist files between (potentially EVILLL) users ... But we'll probably never do that
///             - Can't think of anything else.
///
///         Should we implement custom validation for MMF?
///             - Currently, the most practical solution is to not have untrusted sources. [Feb 2025]
///             - Once we're forced to have untrusted sources, custom validation is probably necessary for some fields of the loaded datastructures (Probably MFDataClasses) – so that we're totally secure against hackers.
///
/// Learnings from MFDeepCopyCoder:
///     (We tried to implement our own coder for deep-copying, but it sucked, but we learned some stuff that is relevant for **deep copying** and **other custom coders**)
///     Learnings:
///     - NSKeyedArchiver/NSKeyedUnarchiver is actually very fast, since it seems to go directly to binary plist, instead of creating a plist object graph like I suspected.
///         Our naive MFDeepCopyCoder implementation which converted the object-graph to a nested NSDictionary and back was only around 20% faster than using NSKeyedArchiver and NSKeyedUnarchiver for deep-copying for my simple tests. So the maintenance overhead seems not worth it.
///     - NSKeyedUnarchiver claims to support cyclical object-graphs but that support actually breaks if -initWithCoder: or -awakeAfterUsingCoder: returns a different object than its receiver.
///         (-initWithCoder: usually returns different instances for class-clusters like NSDictionary and NSArray.)
///         Problem is also described in this GitHub Gist from 8 years ago: https://gist.github.com/Tricertops/354e443283d50497912cd7a1e8c884a1
///         What does this mean for our implementations?
///             - If we try to implement encoding of cyclical object graphs in our custom coder, we'd run into the same problem.
///             - Solution: The only solution I could think of is to box the circularly-referenced parent in an NSProxy, then give that proxy to the child, instead of giving the parent directly, and finally swaping out the boxed instance, if -[parent initWithCoder:] or -[parent awakeAfterUsingCoder:] return a different instance.
///             - ... But it's probably better to just not support cyclical object-graphs unless necessary.
///
/// Also see:
///     - Apple reference on "Archives and Serialization":
///         https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Archiving/Articles/serializing.html#//apple_ref/doc/uid/20000952-BABBEJEE
///     - WWDC talk about `NSSecureCoding`:
///         WWDC 2018 Session 222 "Data You Can Trust": https://devstreaming-cdn.apple.com/videos/wwdc/2018/222krhixqaeggyrn33/222/222_hd_data_you_can_trust.mp4?
///         (This has been deleted from the Apple page for some reason, but their CDN still has the video)
///         -> This explains how and why to use `NSSecureCoding`

#import "MFCoding.h"
#import "WannaBePrefixHeader.h"
#import "SharedUtility.h"
#import "MFPlistDecoder.h"
#import "MFPlistEncoder.h"
#import "EventLoggerForBradMacros.h"

@implementation MFCoding

/// NSCoder wrappers

NSData *MFEncode(NSObject<NSCoding> *codable, BOOL requireSecureCoding, MFEncoding outputArchiveFormat) {
    
    /// On the `requireSecureCoding` arg:
    ///     Enabling secureCoding for an *en*code is pretty unnecessary.
    ///     secureCoding enables additional checks during *de*coding. When you enable it for *en*coding, it doesn't really do anything. The encoded data won't change.
    ///         The only thing it does is it will fail the encode, if the encoded data does not support being *de*coded with secureCoding enabled.
    ///         So the only benefit is that we ensure we fail "early" (during the encode) if we can predict that the *de*code would fail.
    ///             -> I don't know when that's ever important. When it's not important you can leave `requireSecureCoding` off.
    ///         (The object-graph 'supports secureCoding' if all of the objects in the graph (that will actually be encoded) conform to the NSSecureCoding protocol.)
    
    /// Null safety
    if (!codable) return nil; /// This may not be necessary as `NSKeyedArchiver` might behave well if we pass it nil. (Ideally it would just return nil and populate the error)
    
    /// Map output format to NSCoder type
    NSCoder *encoder;
    ({
        switch (outputArchiveFormat) {
            bcase(kMFEncoding_NSKeyed_XML, kMFEncoding_NSKeyed_Binary): {
                encoder = [NSKeyedArchiver alloc];
            }
            bcase(kMFEncoding_MFPlist): {
                encoder = [MFPlistEncoder alloc];
            }
        }
    });
    
    /// Init & configure encoder
    if (isclass(encoder, NSKeyedArchiver)) {
        encoder = [((NSKeyedArchiver *)encoder) initRequiringSecureCoding: requireSecureCoding]; /// Are we sure this can't throw? ... I mean its only input is a boolean, so yeah.
        [((NSKeyedArchiver *)encoder) setOutputFormat: (NSPropertyListFormat)outputArchiveFormat];
    }
    else {
        encoder = [((MFPlistEncoder *)encoder) initRequiringSecureCoding: requireSecureCoding
                                                           failurePolicy: NSDecodingFailurePolicyRaiseException];
    }
    
    /// Archive
    NSData *result;
    NSException *exception;
    BOOL finishEncodingNeedsToBeCalled = isclass(encoder, NSKeyedArchiver);
    ({
        @try {
            [encoder encodeObject: codable forKey: NSKeyedArchiveRootObjectKey]; /// This can throw, at least for MFPlistEncoder
            ifcastn(encoder, NSKeyedArchiver, archiver) {
                [archiver finishEncoding];               /// `-finishEncoding` needs to be called before `-encodedData`.
                finishEncodingNeedsToBeCalled = NO;
                result = [archiver encodedData];         /// I think this can throw since it returns a non-nullable.
            }
            else ifcastn(encoder,MFPlistEncoder, encoder) {
                result = [encoder encodedPlist];
            }
            exception = nil;
        }
        @catch (NSException *exc) {
            if (exc.name != NSInvalidArchiveOperationException) DDLogInfo(@"MFEncode: Unexpected exception with name: %@", exc.name); /// [Late 2024] For some reason, the NSKeyedArchiver's NSSecureCoding-violation exceptions have the `Invalid*Un*archiveOperation` name even thought we're archiving, not *un*archiving.
            result = nil;
            exception = exc;
        }
    });
    if (finishEncodingNeedsToBeCalled)
        [((NSKeyedArchiver *)encoder) finishEncoding]; /// We get a console warning if `-finishEncoding` is not called before the NSKeyedArchiver is deallocated.
    
    /// Log errors
    ///     Caution: If DDLogError() isn't initialized by the point we call this (e.g. in a +[load] method) then these errors will become invisible.
    if (!result || exception) {
        DDLogError(@"MFEncode: %@ encoding problem. Exception: %@", encoder.className, exception);
        assert(false); /// In our app, encoding should only ever fail to due programmer error I think.
    }
    
    /// Return
    return result;
}

id<NSCoding> MFDecode(id archive, BOOL requireSecureCoding, NSSet<Class> *_Nullable expectedClasses, MFEncoding inputArchiveFormat) {
    
    /// On the `requireSecureCoding` arg:
    ///     Leave it off, unless you're decoding data from an *untrusted source* where there's a possibility that a hacker has created/modified the data. E.g. user-submitted data downloaded from a web server.
    ///     > Explanation: See the top of this file under `On **NSSecureCoding**`
    ///
    ///     If `requireSecureCoding == NO` then the `expectedClasses` argument is ignored and can be set to nil.
    ///     If `requireSecureCoding == YES` then `expectedClasses` needs to contain the classes to be decoded from the `data` archive. Otherwise decoding will fail.
    ///
    /// On __structured__ and __unstructured containers__.
    ///     For *structured containers* such as `MFDataClass` instances, `expectedClasses` only needs to contain the class of the root object of the archive (which will be returned from this function), because MFDataClass knows which type its properties have, so it can tell the decoder what the `expectedClasses` are before decoding each of its properties, so we don't need to specify them here.
    ///     However, for *unstructured containers* like NSArray or NSDictionary, they don't know what classes they should contain after being decoded, so *all* of the classes that are part of the "unstructured" section of the datastructure need to be provided by you in the `expectedClasses` argument.
    ///     By 'unstructured section' I mean any elements that you could find by starting at the root of the data structure and then recursively going to each of its members, only stopping once you find a leaf node or a 'structured' datatype (which knows exactly what classes it should contain after decoding).
    ///     ... This sounds pretty theoretical. I might not understand anymore in the future, but it shouldn't matter because:
    ///      In practise you can probably just try it out and adjust the `expectedClasses` based on error messages.
    ///
    ///      Update: [Feb 2025] MFDataClass could also have *unstructured sections*, e.g. when it contains an NSArray, and it doesn't know what's type of object is inside.
    ///             But I think we mostly fixed that by parsing lightweight generics inside of MFDataClass (kinda crazy.)
    
    /// Null safety
    if (!archive) return nil; /// This may not be necessary in case the coders behave well if we pass it nil. (Ideally they would just return nil and populate the error with sth helpful)
    
    
    /// Map input format to NSCoder type
    NSCoder *_Nonnull decoder;
    ({
        switch (inputArchiveFormat) {
        
        bcase(kMFEncoding_NSKeyed_XML, kMFEncoding_NSKeyed_Binary):
            decoder = [NSKeyedUnarchiver alloc];
        
        bcase(kMFEncoding_MFPlist):
            decoder = [MFPlistDecoder alloc];
        }
    });
    
    /// Init decoder
    if (isclass(decoder, NSKeyedUnarchiver)) {
        
        NSError *error;
        decoder = [((NSKeyedUnarchiver *)decoder) initForReadingFromData: archive error: &error];
        
        if (!decoder || error) DDLogError(@"MFDecode: NSKeyedUnarchiver initialization error: %@", error);
        if (!decoder) return nil;
        
        ((NSKeyedUnarchiver *)decoder).requiresSecureCoding  = requireSecureCoding;
        ((NSKeyedUnarchiver *)decoder).decodingFailurePolicy = NSDecodingFailurePolicyRaiseException; /// Use old-school, more robust, objc-only error handling. See top of the file for explanation.
    }
    else if (isclass(decoder, MFPlistDecoder)) {
    
        decoder = [((MFPlistDecoder *)decoder) initForReadingFromPlist: archive
                                                  requiresSecureCoding: requireSecureCoding
                                                         failurePolicy: NSDecodingFailurePolicyRaiseException];
        if (!decoder) {
            assert(false && "MFDecode: MFPlistDecoder initialization failed. This should never happen.");
            return nil;
        }
    }
    else {
        assert(false && "This can never happen");
    }
    
    /// Validate expected classes
    if ((0) && requireSecureCoding)
        assert(expectedClasses != nil && expectedClasses.count > 0); /// Don't have to return here. [decodeObjectOfClasses:] will fail anyways.
    
    /// Unarchive
    ///     Note: We could also use the 'topLevel' APIs to automatically convert internally propagated exceptions into errors.
    ///     However, based on my testing [Feb 2025] this doesn't catch all exceptions. (I tested MFPlistDecoder – exceptions thrown by -[failWithError:]  were caught, but when I directly used @throw during decoding, it wasn't caught.)
    NSObject<NSCoding> *result;
    NSException *exception;
    ({
        @try {
            result = [decoder decodeObjectOfClasses: expectedClasses forKey: NSKeyedArchiveRootObjectKey];
            exception = nil;
        }
        @catch (NSException *exc) {
            if (exc.name != NSInvalidUnarchiveOperationException) DDLogInfo(@"MFDecode: Unexpected exception with name: %@", exc.name);
            result = nil;
            exception = exc;
        }
    });
    
    /// Postprocess decoder
    if (isclass(decoder, NSKeyedUnarchiver)) {
        [((NSKeyedUnarchiver *)decoder) finishDecoding]; /// I'm not sure what this does.
    }
    
    /// Log failure
    if (!result || exception) {
        DDLogError(@"MFDecode: %@ decoding problem. Exception: %@", decoder.className, exception);
        assert(false); /// Get alerted in debug builds
    }
    
    /// Return
    return result;
}

@end

#pragma mark - Outdated dict-archiving

#if 0 /// Outdated

/// ArchiveDict encoding
///     Instead of encoding to/from NSData we can also encode to/from an NSDictionary which holds the NSKeyedArchiver data - The NSDictionary archive should be more transparent for debugging than the pure NSData.
///         We can also embed the dict in another dict (like our configDict) and then serialize the whole thing to a .plist file in a way that's very easily inspectable.
///     Sidenote:
///         Instead of archiving to NSData, we could also archive as a human readable XML string by using the plistFormat`NSPropertyListXMLFormat_v1_0` - this would also be fairly transparent.
///     Possible problem:
///         Using a dictionary archive might also be less robust than the alternatives, since I think the dict's key order and stuff might change after serializing / deserializing which could e.g. affect the hash? (We need the hash to be consistent for offline license validation)
///         ... Yeah I think We should probably stick to the standard binary/xmlString formats for the archive - until we can do more testing proving that the ArchiveDict approach is robust for our use case.
///     Update: [Feb 2025]
///         We've now implemented MFPlistDecoder, which can convert MFDataClass instances to super human-readable plist dictionaries. (This vvv just converted the NSKeyedArchiver archive into a dict which still used weird compression/deduplication techniques and cryptic dict keys and stuff.)

NSDictionary *MFEncodeToArchiveDict(NSObject<NSCoding> *codable, BOOL requireSecureCoding) {

    assert(false); /// Don't use this. See "Possible problem" above.
    
    /// Codable -> Data
    NSData *data = MFEncode(codable, requireSecureCoding, (MFEncoding)NSPropertyListBinaryFormat_v1_0); /// Binary format might  be more efficient than XML
    if (!data) return nil;
    
    /// Data -> Dictionary
    NSError *error;
    NSDictionary *result = [NSPropertyListSerialization propertyListWithData:data
                                                                     options:NSPropertyListImmutable
                                                                      format:nil
                                                                       error:&error];
    if (!result || error) DDLogError(@"MFEncodeToArchiveDict: Deserialization error: %@", error);
    
    /// Validate
    if (result && ![result isKindOfClass:NSDictionary.class]) {
        DDLogError(@"MFEncodeToArchiveDict: Plist data did not decode into an NSDictionary. (Decoded %@ instead) Don't think this can ever happen.", result.class);
        assert(false);
        return nil;
    }
    
    /// Return
    return result;
}
id<NSCoding> MFDecodeFromArchiveDict(NSDictionary *archiveDict, BOOL requireSecureCoding, NSSet<Class> *expectedClasses) {
    
    assert(false);  /// Don't use this. See "Possible problem" above.
    
    /// Null safety
    if (!archiveDict) return nil; /// This may not be necessary as `NSPropertyListSerialization` might behave well if we pass it nil. (Ideally it would just return nil and populate the error)
    
    /// Dictionary -> Data
    NSError *error;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:archiveDict
                                                              format:NSPropertyListBinaryFormat_v1_0
                                                             options:0
                                                               error:&error];
    if (!data || error) DDLogError(@"MFDecodeFromArchiveDict: Serialization error: %@", error);
    if (!data) return nil;
    
    /// Data -> Codable
    id<NSCoding> result = MFDecode(data, requireSecureCoding, expectedClasses);
    
    /// Return
    return result;
}

#endif

#pragma mark - Load Tests

#define MF_TEST 0 /** Using `MF_TEST` consistently seems like a nice convention to make these random, scattered load-tests greppable. */

#if MF_TEST

#import "MFDataClass.h"

@interface MFNSStringXYZ : NSString @end /// Trying to test encoding/decoding of a custom subclass but it's too annoying to make the subclass work.
@implementation MFNSStringXYZ @end

MFDataClass0(MFDataClassBase, TestInner)

MFDataClass4(MFDataClassBase, TestOuter,
            readonly, strong, nonnull,  NSArray<TestInner *> *,         inners              ,
            readonly, strong, nullable, NSString *,                     nullableString      ,
            readonly, strong, nonnull,  NSMutableArray<NSString *> *,   mutableArray        ,
            readonly, strong, nonnull,  NSArray<NSMutableString *> *,   mutableStrings      );



@implementation TestOuter (loaddddd)

+ (void)load {
    
    MFCFRunLoopPerform(CFRunLoopGetMain(), nil, ^{ /// Delay, so that CocoaLumberjack gets initialized (?)
    
        #define Log(x...) NSLog(@"MFCoding Loadtests: " x)
    
        /// Test encoding failure
        __auto_type unencodable_block = ^{ Log(@"Get blocked!"); };
        if ((0)) {
            NSDictionary *block_archive = MFEncode((id)unencodable_block, true, kMFEncoding_MFPlist);
        }
            
        /// Test NSKeyedArchiver NSException -> NSError conversion
        if ((0)) {
            NSError *err;
            [NSKeyedArchiver archivedDataWithRootObject: unencodable_block requiringSecureCoding: true error: &err];
            Log(@"NSKeyedArchiver error: %@", err);
        }
        
        /// Test MFDataClass encode/decode
        TestOuter *outer =
            [[TestOuter alloc] initWith_inners:
                                               @[
                                                    [[TestInner alloc] init],
                                                    [[TestInner alloc] init],
                                                    (id)[NSNull null],
                                                ]
                                nullableString: (1) ? nil : @"Not nil"
                                  mutableArray: (0) ? nil : @[@"a", @"b", @"c"].mutableCopy
                                mutableStrings: @[@"d".mutableCopy, @"e".mutableCopy, @"f".mutableCopy /*, @1 */]
            ];

        NSDictionary *archive = MFEncode(outer, true, kMFEncoding_MFPlist);
        Log(@"TestOuter archive: %@", archive);
        
        TestOuter *reconstructed = (id)MFDecode(archive, true, MFNSSetMake([TestOuter class], [NSNull class]), kMFEncoding_MFPlist);
        Log(@"TestOuter reconstructed: %@", reconstructed);
        
        #undef Log
        
    });
    
}

@end

#endif
