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

/// Factory
+ (instancetype)new {
    id newInstance = [[self alloc] init];
    return newInstance;
}

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
                [copy setValue:[value copyWithZone:zone] forKey:key];
            }
        }
    }
    return copy;
}

/// Equality Check
- (BOOL)isEqual:(id)object {
    
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[self class]]) {
        return NO;
    }
    MFDataClassBase *other = (MFDataClassBase *)object;
    
    for (NSString *key in self.allPropertyNames) {
        id selfValue = [self valueForKey:key];
        id otherValue = [other valueForKey:key];
        if (selfValue != otherValue && ![selfValue isEqual:otherValue]) {
            return NO;
        }
    }
    
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
- (NSArray<NSString *> *)allPropertyNames {
    
    /// Notes:
    /// - We could maybe do some caching here to speed things up
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

@end
