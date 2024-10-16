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
        for (NSString *key in self.allPropertyNames) {
            id value = [coder decodeObjectForKey:key];
            if (value) {
                [self setValue:value forKey:key];
            }
            
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    for (NSString *key in self.allPropertyNames) {
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
        for (NSString *key in self.allPropertyNames) {
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
    if (![object isKindOfClass:[MFDataClassBase class]]) {
        return NO;
    }
    
    /// Unwrap
    MFDataClassBase *other = (MFDataClassBase *)object;
    
    /// Get propertyNames
    NSArray<NSString *> *propertyNames = self.allPropertyNames;
    
    /// Compare propertyNames
    ///     Discussion: This makes it so instances of different `MFDataClass` subclasses can be considered equal if they have the exact same propertyNames and propertyValues. Not sure this is actually useful.
    BOOL propertyNamesMatch;
    if (object_getClass(self) == object_getClass(other)) { /// Note: Is this a valid way to compare class-equality? TODO: Check our Swizzling code to see how we do it there.
        propertyNamesMatch = YES; /// If the class is the same, the propertyNames have to be the same, too
    } else {
        propertyNamesMatch = [propertyNames isEqual:other.allPropertyNames];
    }
    if (!propertyNamesMatch) {
        return NO;
    }
    
    /// Compare propertyValues.
    for (NSString *key in propertyNames) {
        id selfValue = [self valueForKey:key];
        id otherValue = [other valueForKey:key];
        if (selfValue != otherValue && ![selfValue isEqual:otherValue]) {
            return NO;
        }
    }
    
    /// Passed all tests!
    return YES;
}

- (NSUInteger)hash {

    NSUInteger hash = 0;

    for (NSString *key in self.allPropertyNames) {
        id value = [self valueForKey:key];
        hash ^= [value hash];
    }
    
    return hash;
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

- (NSArray<NSString *> *_Nonnull)allPropertyNames {
    
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
    
    for (NSString *propertyName in self.allPropertyNames) {
        id propertyValue = [self valueForKey:propertyName];
        [result addObject:propertyValue];
    }
    
    return result;
}

- (NSDictionary<NSString *, NSObject *> *_Nonnull)asDictionary {
    
    /// Using the KVC method `setValuesForKeysWithDictionary:` for the 'opposite' of this method.
    
    NSDictionary *result = [self dictionaryWithValuesForKeys:self.allPropertyNames];
    return result;
}


@end
