//
// --------------------------------------------------------------------------
// MFDataClass.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "MFDataClass.h"
@import ObjectiveC.runtime;

@implementation MFDataClassBase

/// Protocol implementations

/// Notes on handling primitive properties:
///     The KVC API (`valueForKey:` and `setValue:forKey`) automatically wraps (and unwraps) numbers and structs in `NSNumber` or `NSValue` objects.
///         Source: Apple Docs: KeyValueCoding - Representing Non-Object Values: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/KeyValueCoding/DataTypes.html#//apple_ref/doc/uid/20002171-BAJEAIEE
///     `NSValue` (and its subclass `NSNumber`) also adopt the `NSCopying` and `NSSecureCoding` protocols. On top of this, NSValue also implements the`hash` and `isEqual:`methods in a proper way (and it works even if you box custom structs - From my limited testing).
///     -> Because of this, we don't need much primitive-value-specific code - NSValue and KVC does it all for us!
///         (Where 'primitive-value' means any non-object value that KVC is compatible with, such as c numbers and structs. Other c types like unions don't work with KVC I heard, and therefore might break `MFDataClass`.)

/// NSCoding protocol
    
- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        for (NSString *key in self.class.allPropertyNames) {
            id value = [coder decodeObjectForKey:key];
            if (value) {
                [self setValue:value forKey:key];
            }
            
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    for (NSString *key in self.class.allPropertyNames) {
        id value = [self valueForKey:key];
        if (value) {
            [coder encodeObject:value forKey:key];
        }
    }
}

/// NSCopying Protocol
- (id)copyWithZone:(NSZone *)zone {
    MFDataClassBase *copy = [[[self class] allocWithZone:zone] init];
    if (copy) {
        for (NSString *key in self.class.allPropertyNames) {
            id value = [self valueForKey:key];
            if (value) {
                if ([[self class] propertyIsValueType:key]) {
                    [copy setValue:value forKey:key]; /// Primitive-value-specific logic is probably not necessary, since `NSValue` and `NSNumber` (which our primitive values will be boxed in by KVC) adopt the `NSCopying` protocol - it might be more efficent though?
                } else {
                    [copy setValue:[value copyWithZone:zone] forKey:key];
                }
            }
        }
    }
    return copy;
}

/// Override NSObject Equality/Hashing methods:
- (BOOL)isEqual:(id)object {
    
    /// Trivial cases
    if (object == nil) {
        return NO;
    }
    if (self == object) {
        return YES;
    }
    if (object_getClass(self) != object_getClass(object)) { /// Note: Is this a valid way to compare class-equality? TODO: Check our Swizzling code to see how we do it there.
        return NO;
    }
    
    /// Unwrap other
    MFDataClassBase *other = (MFDataClassBase *)object;
    
    /// Compare propertyValues
    if (![self.propertyValuesForEqualityComparison isEqual:other.propertyValuesForEqualityComparison]) {
        return NO;
    }
    
    /// Passed all tests!
    return YES;
}

- (NSUInteger)hash {
    NSUInteger result = self.propertyValuesForEqualityComparison.hash;
    return result;
}

/// Utility

+ (BOOL)propertyIsValueType:(NSString *)propertyName {
    
    objc_property_t property = class_getProperty([self class], [propertyName cStringUsingEncoding:NSUTF8StringEncoding]); /// Why UTF8? Quote from Objective-C runtime docs: `All char * in the runtime API should be considered to have UTF-8 encoding.`
    if (!property) {
        assert(false);
        return NO;
    }
    
    const char *attributes = property_getAttributes(property);
    if (!attributes || strlen(attributes) < 2) {
        assert(false);
        return NO;
    }
    
    BOOL isObjectType = attributes[1] == '@'; /// See Apple docs for explanation of the format of the attributes-string: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html#//apple_ref/doc/uid/TP40008048-CH101
    
    return !isObjectType;
}

+ (NSArray<NSString *> *_Nonnull)allPropertyNames {
    
    /// Notes:
    /// - This is used by almost all other methods - We could maybe do some caching here to speed things up
    /// -> Maybe cache the c-string property name list.
    ///     If we cache the result and just return that every time then this will break if properties are added at runtime. (Which I'm not sure is relevant for these DataClasses)
    
    NSMutableArray *result = [NSMutableArray array];
    
    unsigned int propertyCount, i;
    objc_property_t *properties = class_copyPropertyList([self class], &propertyCount);
    
    for (i = 0; i < propertyCount; i++) {
        objc_property_t property = properties[i];
        const char *propName = property_getName(property);
        if (propName) {
            [result addObject:[NSString stringWithUTF8String:propName]];
        }
    }
    
    free(properties);
    
    return result;
}

- (NSArray<id> *_Nonnull)allPropertyValues {
    
    NSMutableArray *result = [NSMutableArray array];
    
    for (NSString *propertyName in self.class.allPropertyNames) {
        id propertyValue = [self valueForKey:propertyName];
        [result addObject:propertyValue];
    }
    
    return result;
}

- (NSArray<id> *_Nonnull)propertyValuesForEqualityComparison; {

    /// Client code can override this (in a category) to easily change the definition of equality
    ///     (This will also automatically change `hash`, so that hashing and equality definitions match.)
    ///     On property order:
    ///         The order of the property values in the returned array needs to always be the same, otherwise our equality and hash methods that depend on this will break.
    ///         For the default implementation this should be ensured since the underlying function `class_copyPropertyList()` seems to output the properties in deterministic order based on my testing.
    ///         If order ever does cause breakage, perhaps we could return an `NSSet` instead of `NSArray`
    ///
    return [self allPropertyValues];
}

- (NSDictionary<NSString *, NSObject *> *_Nonnull)asDictionary {
    
    /// Using the KVC method `setValuesForKeysWithDictionary:` for the 'opposite' of this method.
    
    NSDictionary *result = [self dictionaryWithValuesForKeys:self.class.allPropertyNames];
    return result;
}


@end
