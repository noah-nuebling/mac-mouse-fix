//
// --------------------------------------------------------------------------
// MFDeepCopyCoder.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// This is was an experiment. (Last updated [Feb 2025])
/// We tried to create an NSCoder optimized for deep-copying, by simply converting the object-graph to a nested NSDictionary and back.
///     However, this was only around 20% faster than using NSKeyedArchiver and NSKeyedUnarchiver for deep-copying for my simple tests. So the maintenance overhead seems not worth it.

/// The interesting learnings from this have been moved to other files like MFCoding.m and MFPlistDecoder
/// > **You can delete this.**
///
/// Optimization Ideas I had afterwards: (Before we actually delete this, we could try these)
///     - We used NSDictionary as the archive. Perhapsss using NSMapTable would've been faster? ... But I don't really think so since I think the only overhead of NSDictionary is to call -hash and -isEqual: and -copy on the keys, which were all immutable NSStrings in our case (So it should be very fast.)
///     - We used NSMutableArray and NSMutableDictionary when encoding/decoding plist container archive nodes. Instead we could put the contained objects on the stack to manipulate them (Doing that in MFPlistCoder as of [Feb 2025])

#if 0 /// Unused

/// Reference:
///     https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Archiving/Articles/serializing.html#//apple_ref/doc/uid/20000952-BABBEJEE
///
/// - Todo:
///     - Handle NSData :: Done
///     - Handle non-keyed coding :: Not Done
///     - Handle section in reference: "Making Substitutions During Coding" :: Done
///         Call classForCoder and stuff.
///     - Handle initWithCoder: returning other object (for decoding cyclical references) :: Done (Actually impossible to do properly)
///         See section in reference: "This is done in the subclass because the superclass, in its implementation of initWithCoder:, may decide to return an object other than itself"

#import "MFDeepCopyCoder.h"
#import "MFPlistEncoder.h"
#import "SharedUtility.h"
#import "objc/runtime.h"

@interface MFDeepCopyCoder_Placeholder : NSObject
    {
        @public
        enum placeholder_type {
            placeholder_type_nil,
            placeholder_type_keypath,
        };
        enum placeholder_type _type;
        NSMutableArray *_keyPath;
    }
@end

@implementation MFDeepCopyCoder_Placeholder

    + (instancetype) keyPath: (NSMutableArray<NSString *> *) keyPath {
        MFDeepCopyCoder_Placeholder *result = [self alloc];
        result->_type = placeholder_type_keypath;
        result->_keyPath = keyPath;
        return result;
    }

    + (instancetype) null {
        MFDeepCopyCoder_Placeholder *result = [self alloc];
        result->_type = placeholder_type_nil;
        return result;
    }

@end

@implementation MFDeepCopyCoder
    {
        id _Nullable _archive;
        id _Nullable _reconstruction;
        
        /// Recursion storage for encode
        NSMutableSet                            *_visitedObjects ;
        NSMutableArray<NSString *>              *_keyPath        ;
        
        /// Recursion storage for encode & decode
        NSMutableArray<NSMutableDictionary *>   *_dictStack      ;
    }

    - (BOOL)                    allowsKeyedCoding       { return YES; }
    - (BOOL)                    requiresSecureCoding    { return NO; }
    - (NSDecodingFailurePolicy) decodingFailurePolicy   { return -1; } /// Can't fail
    - (unsigned int)            systemVersion           { return 0; }            /// No idea what this is or how to use it, but the docs told me to override this IIRC
    - (NSError *)               error                   { return nil; }

    - (void)failWithError:(NSError *)error {
        assert(false && "Not implemented");
    }
    
    - (instancetype)init
    {
        self = [super init];
        if (!self) return nil;
        
        _archive = nil;
        
        _visitedObjects = [NSMutableSet set];
        _dictStack      = [NSMutableArray array];
        _keyPath        = [NSMutableArray array];
        
        return self;
    }
    
    + (id) deepCopyOf: (id)obj {
        
        /// Main interface
        if (!obj) return nil;
        MFDeepCopyCoder *coder = [[MFDeepCopyCoder alloc] init];
        [coder encodeObject: obj forKey: NSKeyedArchiveRootObjectKey];
        id result = [coder decodeObjectForKey: NSKeyedArchiveRootObjectKey];
        return result;
    }
    
    #define MFDeepCopyCoder_ArchiveKey_Class              @"___MFDeepCopyCoder_Key_Class___"
    #define MFDeepCopyCoder_ArchiveKey_ObjectCache        @"___MFDeepCopyCoder_Key_ObjectCache___"
    #define MFDeepCopyCoder_ArchiveKey_ObjectCacheWasUsed @"___MFDeepCopyCoder_ArchiveKey_ObjectCacheWasUsed___"
    
    #pragma mark - Underlying raw encode/decode methods
    
    - (id _Nullable) _encodingForObject: (id)object {
        
        /// Declare encoding
        id encoding = nil;
        
        if (!object) {
            /// Encode nil
            encoding = [MFDeepCopyCoder_Placeholder null];
        }
        else if (((0)) && /// We broke keypaths
                    [_visitedObjects containsObject: object])
        {
            /// Deduplicate cyclical references
            ///     Note that we're not deduplicating any duplicate objects in the object-graph. Only cyclical references – meaning places where a child references its parent.
            encoding = [MFDeepCopyCoder_Placeholder keyPath: _keyPath];
        }
        else if (isclass(object, NSArray)) {
            
            encoding = [object mutableCopy];
            for (int i = 0; i < [encoding count]; i++) {
                id e = [self _encodingForObject: encoding[i]];
                encoding[i] = e;
            }
        }
        else if ((1) && MFPlistIsValidNode(object) && !isclass(object, NSDictionary)) {
        
            /// Simply copy non-recursive plist types.
            ///     We know these have now children we need to copy.
            encoding = [object copy];
        
        } else {
            /// Encoding substitutions
            ///     Notes:
            ///     - should we use -[object classForKeyedArchiver:] -[object replacementObjectForKeyedArchiver:] ?
            ///     - Docs mention that NSCoder calls these. So do we have to call them directly?
            ///     - See: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Archiving/Articles/codingobjects.html#//apple_ref/doc/uid/20000948-97072-BAJJBCHI
            id replObj = [object replacementObjectForCoder: self];
            if (replObj) object = replObj;
            Class classForCoder = [object classForCoder];
            [[[NSKeyedUnarchiver alloc] init] classForClassName:@"" ];
            
            /// Create encoding dict
            encoding = [NSMutableDictionary dictionary];
            encoding[MFDeepCopyCoder_ArchiveKey_Class] = classForCoder; /// Storing the class object directly
            
            /// Push/pop dictStack
            [_dictStack addObject: encoding];
            MFDefer ^{ [self->_dictStack removeLastObject]; };
            
            /// Push/pop visitedObjects
            if ((0)) { /// Keypaths are broken
                if (object) [_visitedObjects addObject: object];
                MFDefer ^{ if (object) [self->_visitedObjects removeObject: object]; };
            }
            
            /// Recurse
            ///     object will encode itself into the top of the dictStack
            [object encodeWithCoder: self];
        }
        
        /// Return
        return encoding;
    }
    
    - (id _Nullable) _decodeEncoding: (id)encoding {

        /// Declare result
        id _Nullable result = nil;
        
        if (isclass(encoding, MFDeepCopyCoder_Placeholder)) {
            
            /// Cast to placeholder
            MFDeepCopyCoder_Placeholder *placeholder = encoding;
            
            /// Decode placeholder
            if (placeholder->_type == placeholder_type_nil) {
                /// Insert nil
                result = nil;
            }
            else if (placeholder->_type == placeholder_type_keypath) {
                
                assert(false); /// We broke keypaths for performance.
                
                /// Insert circular reference to a parent in the object-graph.
                NSString *keyPathStr = [placeholder->_keyPath componentsJoinedByString: @"."]; /// This codepath is rare, so doing the toString conversion on the keypath here, uncached, shouldn't matter.
                NSMutableDictionary *archiveNode = keyPathStr.length == 0 ? _archive : [_archive valueForKeyPath: keyPathStr];
                id cachedObject = archiveNode[MFDeepCopyCoder_ArchiveKey_ObjectCache];
                archiveNode[MFDeepCopyCoder_ArchiveKey_ObjectCacheWasUsed] = @YES;
                assert(cachedObject);
                result = cachedObject;
                
            } else {
                assert(false);
            }
        }
        if (isclass(encoding, NSArray)) {
            /// Encode NSArray directly for performance.
            ///     NSKeyedArchiver seems to do this, too.
            ///     NOTE: This will break the keypaths we currently use to detect cycles.
            
            result = [encoding mutableCopy];
            
            for (int i = 0; i < [result count]; i++) {
                id decoded = [self _decodeEncoding: result[i]];
                [result setObject: decoded atIndex: i];
            }
            
        }
        else if ((1) && MFPlistIsValidNode(encoding) && !isclass(encoding, NSDictionary)) {
            /// Non-container plist
            result = encoding;
        }
        else {
            /// Cast to dict
            assert(isclass(encoding, NSMutableDictionary));
            NSMutableDictionary *dict = encoding;
            
            /// Extract class
            Class cls = dict[MFDeepCopyCoder_ArchiveKey_Class];
            assert(cls);
            
            /// Push & pop dictStack
            [_dictStack addObject: dict];
            MFDefer ^{ [self->_dictStack removeLastObject]; };
            
            /// Alloc
            result = [cls alloc];
            
            /// Cache +alloc in the archive
            ///     So children initialized by -initWithCoder: can resolve cyclical references
            if ((0)) /// Keypaths are broken
                dict[MFDeepCopyCoder_ArchiveKey_ObjectCache] = result;
            
            /// Init / Recurse
            ///     The object will init itself using the top of the dictStack.
            id result_preInit = result;
            result = [result initWithCoder: self];
            
            /// Decoding substitutions
            ///     NSKeyedUnarchiver has -classForClassName:, but NSCoder doesn't, so we're not implementing that here.
            id result_preAwake = result;
            result = [result awakeAfterUsingCoder: self];
            
            /// Validate that cyclical references are correct.
            ///     Our cyclical-reference-reconstruction breaks, if -initWithCoder: or -awakeAfterUsingCoder: returns a different instance for an object that is cyclically referenced.
            ///         (-initWithCoder: usually returns different instances for class-clusters like NSDictionary and NSArray.)
            ///     Tested [Feb 2025]: Cyclical NSDictionary fails to decode correctly.
            ///     Tested [Feb 2025]: The exact same problem seems to occur with NSKeyedUnarchiver.
            ///         Problem is also described in this GitHub Gist from 8 years ago: https://gist.github.com/Tricertops/354e443283d50497912cd7a1e8c884a1
            ///     Solution?:
            ///         The only solution I could think of is to box the circularly-referenced parent in an NSProxy, and then swap out the boxed instance, if -initWithCoder: or -awakeAfterUsingCoder: return a different instance.
            ///         But since NSKeyedArchiver has the same restriction, we'll just let it rest, and assert(false) if this happens.
            
            if ((0)) /// Keypaths are broken
                if ([dict[MFDeepCopyCoder_ArchiveKey_ObjectCacheWasUsed] isEqual: @YES]) {
                    assert(result == result_preInit  && "The result of +alloc was referenced somewhere else in the object-graph, but -initWithCoder:           returned another instance, so the reference is invalid.");
                    assert(result == result_preAwake && "The result of +alloc was referenced somewhere else in the object-graph, but -awakeAfterUsingCoder:    returned another instance, so the reference is invalid.");
                }
        }
        
        /// Return
        return result;
    }
    
    - (void) _storeEncodingInArchive: (id)encoding forKey: (NSString * _Nonnull)key {
        
        bool isRootKey = [key isEqual: NSKeyedArchiveRootObjectKey]; /// Duplicate calculation on most code-paths.
        
        if (!isRootKey) {
            assert(_dictStack.count > 0);
            [[_dictStack lastObject] setObject: encoding forKey: key];
        }
        else {
            assert(_archive == nil);
            _archive = encoding;
        }
    }
    
    - (id) _retrieveEncodingFromArchiveForKey: (NSString * _Nonnull)key {
        
        bool isRootKey = [key isEqual: NSKeyedArchiveRootObjectKey];
        
        /// Get encoded value from archive
        id encoding;
        if (!isRootKey) {
            assert(_dictStack.count > 0);
            encoding = _dictStack.lastObject[key];
        }
        else {
            assert(_archive);
            encoding = _archive;
        }
        
        return encoding;
    }
    
    
    #pragma mark - Interface – key based encode/decode methods.
    
    - (BOOL) containsValueForKey: (NSString *)key {
        return _dictStack.lastObject[key] != nil;
    }

    - (void) encodeObject: (id)object forKey: (NSString *)key {
        
        /// Push/pop keyPath
        if ((0)) { /// Keypaths are broken
            bool isRootKey = [key isEqual: NSKeyedArchiveRootObjectKey];
            if (!isRootKey) [_keyPath addObject: key]; /// Ignore the root key so that this is a valid keypath relative to the root object
            MFDefer ^{ if (!isRootKey) [self->_keyPath removeLastObject]; };
        }
        
        /// Encode
        id encoding = [self _encodingForObject: object];
        
        /// Store encoding in the archive
        [self _storeEncodingInArchive:encoding forKey:key];
    }

    - (id) decodeObjectForKey: (NSString *)key {
        
        /// Preprocess
        id encoding = [self _retrieveEncodingFromArchiveForKey:key];
        
        /// Decode
        id _Nullable decoded = [self _decodeEncoding:encoding];
        
        /// Return
        return decoded;
    }
    
    - (void)encodeBytes: (const uint8_t *)bytes length: (NSUInteger)length forKey: (NSString *)key {
        
        /// Used by NSString, probably others
        
        NSData *result = [[NSData alloc] initWithBytes: bytes length: length]; /// Should we use the NoCopy variants here?
        [self _storeEncodingInArchive:result forKey:key];
    }
    
    - (const uint8_t *) decodeBytesForKey: (NSString *)key returnedLength: (NSUInteger *)lengthp {
        
        NSData *data = _dictStack.lastObject[key];
        assert(isclass(data, NSData));
        
        *lengthp = [data length];
        return [data bytes];
    }

@end


#define MF_TEST 0
#if MF_TEST

@implementation NSKeyedUnarchiver_Tester : NSKeyedUnarchiver

    - (id) decodeObjectForKey: (NSString *)key {
        return [super decodeObjectForKey: key];
    }

@end


@implementation NSKeyedArchiver_Tester : NSKeyedArchiver

    - (void) encodeObject: (id)object forKey: (NSString *)key {
        [super encodeObject: object forKey: key];
    }

@end

@implementation MFDeepCopyCoder (LoadTests)

+ (void) load {
    
    /// Test by Claude AI
    
    #define Log(x...) NSLog(@"MFDeepCopyCoder LoadTest: " x);
    
    // Create a structure with cycles
    NSMutableDictionary *dict1 = [NSMutableDictionary dictionary];
    NSMutableDictionary *dict2 = [NSMutableDictionary dictionary];
    NSMutableArray *array1 = [NSMutableArray array];

    dict1[@"name"] = @"dict1";
    dict1[@"array"] = array1;
    dict1[@"friend"] = dict2;

    dict2[@"name"] = @"dict2";
    dict2[@"backRef"] = dict1;  // Creates a cycle

    [array1 addObject:dict1];  // Another cycle
    [array1 addObject:dict2];
    [array1 addObject:@"some string"];

    Log(@"Original structure:");
    Log(@"dict1: %p", dict1);
    Log(@"dict2: %p", dict2);
    Log(@"array1: %p", array1);
    
    // Create non-cycled structure
    NSDictionary *dictn = @{
        @"Hi": @"There",
        @"I": @"Like",
        @"These": @"Fish",
        @"Here": @[@"Coy", @"Carp", @"You"],
        @"JustKidding": @"Ihateeverything",
        @"SameStructureAgainKinda": @{
                @"Hi": @"There",
                @"I": @"Like",
                @"These": @"Fish",
                @"Here": @[@"Coy", @"Carp", @"You"],
                @"JustKidding": @"Ihateeverything",
        }
    };
    
    // Test deep copy
    bool testCyclical = false;
    NSDictionary *toCopy = testCyclical ? dict1 : dictn;
    
    NSDictionary *copiedDict;
    
    for (int i = 0; i < 2; i++) {
        
        int nsamples = 1000;
        CFTimeInterval samples[nsamples * 2];
        int samplesi = 0;
        
        for (int j = 0; j < nsamples; j++) {
        
            samples[samplesi++] = CACurrentMediaTime();
        
            if (i == 0) {
                if ((0)) Log(@"Testing MFDeepCopyCoder:");
                copiedDict = [MFDeepCopyCoder deepCopyOf: toCopy];
            }
            else {
                Log(@"Testing NSKeyedArchiver:");
                NSError *err;
                id archive = [NSKeyedArchiver archivedDataWithRootObject: toCopy requiringSecureCoding: NO error: &err];
                if ((0)) Log("err: %@", err);
                if ((0)) {
                    id readableArchive = [NSPropertyListSerialization propertyListWithData: archive options: 0 format: nil error: &err];
                    Log("err: %@ || archive: %@", err, readableArchive);
                }
                NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData: archive error: &err];
                if ((0)) Log("err: %@", err);
                unarchiver.requiresSecureCoding = NO;
                copiedDict = [unarchiver decodeTopLevelObjectForKey: NSKeyedArchiveRootObjectKey error: &err];
                if ((0)) Log("err: %@", err);
            }
            
            samples[samplesi++] = CACurrentMediaTime();
        }
        
        // Log timing
        CFTimeInterval total = 0;
        CFTimeInterval avg = 0;
        for (int i = 0; i < nsamples; i++) {
            CFTimeInterval diff = samples[(i*2)+1] - samples[i*2];
            total += diff;
            avg += diff / nsamples;
        }
        Log(@"Deep copy took avg time: %f ms, total time: %f ms", avg*1000, total*1000);
        
    }
    
    if (testCyclical) {
    
        // Verify the copy worked
        Log(@"\nCopied structure:");
        Log(@"copiedDict: %p", copiedDict);
        Log(@"copiedDict.friend: %p", copiedDict[@"friend"]);
        Log(@"copiedDict.array: %p", copiedDict[@"array"]);

        Log(@"\nChecking if copy worked:");
        Log(@"Are dict1 and copiedDict different instances? %@", (copiedDict != dict1) ? @"Yes" : @"No");
        Log(@"Is name preserved? %@", [copiedDict[@"name"] isEqual:@"dict1"] ? @"Yes" : @"No");

        NSArray *copiedArray = copiedDict[@"array"];
        Log(@"\nChecking cycles:");
        Log(@"Cycle 1 - Is array[0] same as copiedDict? %@",
              ([copiedArray objectAtIndex:0] == copiedDict) ? @"Yes" : @"No");
        Log(@"Cycle 2 - Is friend.backRef same as copiedDict? %@",
              ([(NSDictionary *)copiedDict[@"friend"] objectForKey:@"backRef"] == copiedDict) ? @"Yes" : @"No");

        Log(@"\nFull copied structure:");
        Log(@"%@", copiedDict);
    }
    
    #undef Log
    
}


@end
    
#endif
