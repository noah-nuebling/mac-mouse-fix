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
/// Note on handling errors & exception:
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

#import "MFCoding.h"
#import "WannaBePrefixHeader.h"
#import "SharedUtility.h"

@implementation MFCoding

/// NSKeyedArchiver wrappers

NSData *MFEncode(NSObject<NSCoding> *codable, BOOL requireSecureCoding, NSPropertyListFormat outputFormat) {
    
    /// On the `outputFormat` argument:
    ///     Default to using `outputFormat = NSPropertyListBinaryFormat_v1_0` - it should be the most efficient.
    ///     When using `outputFormat = NSPropertyListXMLFormat_v1_0` you can pass the result to [NSString -initWithData:] to get a human-readable XML string, which might be useful for debugging / transparency for users.
    ///
    /// On the `requireSecureCoding` argument:
    ///     Enabling secureCoding for an *en*code is pretty unnecessary.
    ///     secureCoding enables additional checks during *de*coding. When you enable it for *en*coding, it doesn't really do anything. The encoded data won't change.
    ///         The only thing it does is it will fail the encode, if the encoded data does not support being *de*coded with secureCoding enabled.
    ///         So the only benefit is that we ensure we fail "early" (during the encode) if we can predict that the decode would fail.
    ///             -> I don't know when that's ever important. Wnen it's not important you can leave `requireSecureCoding` off.
    ///         (The object-graph 'supports secureCoding' if all of the objects in the graph which will be encoded conform to the NSSecureCoding protocol.)
    
    /// Null safety
    if (!codable) return nil; /// This may not be necessary as `NSKeyedArchiver` might behave well if we pass it nil. (Ideally it would just return nil and populate the error)
    
    /// Init & configure archiver
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:requireSecureCoding];
    archiver.outputFormat = outputFormat;
    
    /// Archive
    NSData *result;
    NSException *exception;
    BOOL finishEncodingHasBeenCalled = NO;
    @try {
        [archiver encodeObject:codable forKey:NSKeyedArchiveRootObjectKey]; /// I'm not sure this can throw, but I feel like it can.
        [archiver finishEncoding]; /// `-finishEncoding` needs to be called before `-encodedData`.
        finishEncodingHasBeenCalled = YES;
        result = [archiver encodedData]; /// I think this can throw since it returns a non-nullable.
        exception = nil;
    } @catch (NSException *exc) {
        if (exc.name != NSInvalidArchiveOperationException) DDLogInfo(@"MFEncode: Unexpected exception with name: %@", exc.name); /// For some reason, the NSSecureCoding-violation exceptions have the `Invalid*Un*archiveOperation` name even thought we're archiving, not *un*archiving.
        result = nil;
        exception = exc;
    }
    if (!finishEncodingHasBeenCalled) [archiver finishEncoding]; /// We get a console warning if `-finishEncoding` is not called before the archiver is deallocated.
    
    /// Log errors
    if (!result || exception) {
        assert(false); /// In our app, encoding should only ever fail to due programmer error I think. 
        DDLogError(@"MFEncode: NSKeyedArchiver encoding problem. Exception: %@", exception);
    }
    
    /// Return
    return result;
}

NSObject<NSCoding> *MFDecode(NSData *data, BOOL requireSecureCoding, NSArray<Class> *expectedClasses) {
    
    /// On the `requireSecureCoding` argument:
    ///     secureCoding turns on additional validations of the decoded objects to protect against hackers. Leave it off, unless you're decoding data from an *untrusted source* where there's a possibility that a hacker has created/modified the data. E.g. user-submitted data downloaded from a web server.
    ///     If you *are* decoding data from an untrusted source, you should probably not rely solely on built in secureCoding validation and **do additional validation** of the decoded data to actually be secure.
    ///     In some cases the additional validation from secureCoding can be desirable for other purposes. For example if you're decoding an outdated archive of an `MFDataClass` which has different types for its properties, secureCoding would make the decode fail instead of producing an object containing unexpected types or nils - which might crash the app or produce weird bugs when you try to interact with them.
    ///         Find further discussions about `NSSecureCoding` at `MFDataClass.m > -initWithCoder:`
    ///
    ///     If `requireSecureCoding == NO` then the `expectedClasses` argument is ignored and can be set to nil.
    ///     If `requireSecureCoding == YES` then `expectedClasses` needs to contain the classes to be decoded from the `data` archive. Otherwise decoding will fail.
    ///         For structured datatypes like `MFDataClass` instances, `expectedClasses` only needs to contain the class of the root object of the archive (which will be returned from this function), because MFDataClass knows which type its properties have, so it can tell the decoder what the `expectedClasses` are before decoding each of its properties, so we don't need to specify them here.
    ///             However, for unstructured dataTypes like NSArray or NSDictionary, they don't know what classes they should contain after being decoded, so *all* of the classes that are part of the "unstructured" section of the datastructure need to be provided by you in the `expectedClasses` argument.
    ///             By 'unstructured section' I mean any elements that you could find by starting at the root of the data structure and then recursively going to each of its members, only stopping once you find a leaf node or a 'structured' datatype (which knows exactly what classes it should contain after decoding).
    ///             ... This sounds pretty theoretical. I might not understand anymore in the future, but it shouldn't matter because:
    ///              In practise you can probably just try it out and adjust the `expectedClasses` based on error messages.
    
    /// Null safety
    if (!data) return nil; /// This may not be necessary as `NSKeyedUnarchiver` might behave well if we pass it nil. (Ideally it would just return nil and populate the error)
    
    /// Init unarchiver
    NSError *error;
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error];
    if (!unarchiver || error) DDLogError(@"MFDecode: NSKeyedUnarchiver initialization error: %@", error);
    if (!unarchiver) return nil;
    
    /// Configure unarchiver
    unarchiver.decodingFailurePolicy = NSDecodingFailurePolicyRaiseException; /// Use old-school, more robust, objc-only error handling. See top of the file for explanation.
    unarchiver.requiresSecureCoding = requireSecureCoding;
    
    /// Preprocess / validate expected classes
    NSSet<Class> *expectedClassesSet = expectedClasses ? [NSSet setWithArray:expectedClasses] : nil; /// We let user pass in NSArray instead of NSSet because it's easier to use with the `@[]` literal.
    if (requireSecureCoding) assert(expectedClassesSet != nil && expectedClassesSet.count > 0);
    
    /// Unarchive
    NSObject<NSCoding> *result;
    NSException *exception;
    @try {
        result = [unarchiver decodeObjectOfClasses:expectedClassesSet forKey:NSKeyedArchiveRootObjectKey];
        exception = nil;
    } @catch (NSException *exc) {
        if (exc.name != NSInvalidUnarchiveOperationException) DDLogInfo(@"MFEncode: Unexpected exception with name: %@", exc.name);
        result = nil;
        exception = exc;
    }
    [unarchiver finishDecoding];

    if (!result || exception) DDLogError(@"MFDecode: NSKeyedUnarchiver decoding problem. Exception: %@", exception);
    
    /// Return
    return result;
}

/// ArchiveDict encoding
///     Instead of encoding to/from NSData we can also encode to/from an NSDictionary - The NSDictionary archive should be more transparent for debugging than the pure NSData.
///         We can also embed the dict in another dict (like our configDict) and then serialize the whole thing to a .plist file in a way that's very easily inspectable.
///     Sidenote:
///         Instead of archiving to NSData, we could also archive as a human readable XML string by using the plistFormat`NSPropertyListXMLFormat_v1_0` - this would also be fairly transparent.
///     Possible problem:
///         Using a dictionary archive might also be less robust than the alternatives, since I think the dict's key order and stuff might change after serializing / deserializing which could e.g. affect the hash? (We need the hash to be consistent for offline license validation)
///         ... Yeah I think We should probably stick to the standard binary/xmlString formats for the archive - until we can do more testing proving that the ArchiveDict approach is robust for our use case.

NSDictionary *MFEncodeToArchiveDict(NSObject<NSCoding> *codable, BOOL requireSecureCoding) {

    assert(false); /// Don't use this. See "Possible problem" above.
    
    /// Codable -> Data
    NSData *data = MFEncode(codable, requireSecureCoding, NSPropertyListBinaryFormat_v1_0); /// Binary format might  be more efficient than XML
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
NSObject<NSCoding> *MFDecodeFromArchiveDict(NSDictionary *archiveDict, BOOL requireSecureCoding, NSArray<Class> *expectedClasses) {
    
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
    NSObject<NSCoding> *result = MFDecode(data, requireSecureCoding, expectedClasses);
    
    /// Return
    return result;
}

@end
