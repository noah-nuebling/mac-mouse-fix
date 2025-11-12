//
//  MFSimpleDataClass.m
//  another-mfdataclass
//
//  Created by Noah Nübling on 10.11.25.
//

#import "MFSimpleDataClass.h"

#define auto __auto_type

#define charset(str)            [NSCharacterSet characterSetWithCharactersInString: (str)]

#define stringf(fmt, args...)    [NSString stringWithFormat: fmt, ##args]

static NSCharacterSet *charset_words(void) {
    static NSCharacterSet *result;
    static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{
        result = charset(@"" /// `[a-zA-Z_]` aka `\w` aka 'word' characters aka characters that can be part of a c identifier. (I think in clang half of unicode letters can be part of an identifier but that's for crazy ppl)
            "abcdefghijklmnopqrstuvwxyz"
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            "0123456789"
            "_"
        );
    });
    return result;
}

static NSString *indentedString(int n, NSString *s) {
    
    auto lines = [s componentsSeparatedByString: @"\n"];
    auto result = [NSMutableString new];
    
    auto indent = [NSMutableString new];
    for (int i = 0; i < n; i++) [indent appendString: @" "];
    
    int i = 0;
    for (NSString *line in lines) {
        if (i) [result appendString: @"\n"];
        if (i) [result appendString: indent];
        [result appendString: line];
        i++;
    }
    
    return result;
}

@implementation MFSimpleDataClassBase

    + (NSArray<NSString *> *) ivarNames { /// This is called a lot and should perhaps be cached [Nov 2025]
        
        /// Subclassing support || This is the only code needed to support subclassing (Aside from the `mfdata_subcls_h` macro). Not too bad. [Nov 2025]
            
        NSMutableArray *superclasses = [NSMutableArray new];
        Class cls = [self class];
        while (1) {
            if (cls == [MFSimpleDataClassBase class]) break; /// NSObject has `isa` ivar which we wanna ignore [Nov 2025]
            [superclasses insertObject: cls atIndex: 0];     /// Invert order for nicer `-description`
            cls = class_getSuperclass(cls);
        }
            
        NSMutableArray *result = [NSMutableArray new];
        
        for (NSUInteger i = 0; i < superclasses.count; i++) {
            
            Ivar *ivars = class_copyIvarList(superclasses[i], NULL);
            Ivar *ivar = ivars;
            
            while (*ivar) [result addObject: @(ivar_getName(*ivar++))];
            
            free(ivars);
        }
        
        return result;
    }
    - (NSArray<NSString *> *) ivarNames { return [[self class] ivarNames]; }

    - (NSString *) description {
            
            auto result = [NSMutableString new];
            
            [result appendFormat: @"%@ <%p> {", [self className], self];
            
            int i = 0;
            for (NSString *ivar in [self ivarNames]) {
                if (i) [result appendString: @","];
                [result appendString: @"\n"];
                
                auto itemDesc = [[self valueForKey: ivar] description];
                if ([itemDesc containsString: @"\n"])   [result appendString: stringf(@"    .%@ = %@", ivar, indentedString(4, itemDesc))];
                else                                    [result appendString: stringf(@"    .%@ = %@", ivar, itemDesc)];
                i++;
            }
            if (i) [result appendString: @"\n"];
            [result appendString: @"}"];
            
            return result;
        }
        
        - (NSUInteger) hash {
            return [self ivarNames].count; /// NSDictionary needs hash to never change, that's why mutable object's `-[hash]` should not depend on internal state [Nov 2025]  || NSDictionary also just returns its key-count as the hash, so I guess it's ok {Nov 2025]
        }
        
        - (BOOL) isEqual: (id)other {
        
            if (other == self) return YES;
            
            for (NSString *ivar in [self ivarNames]) {
                id ours = [self valueForKey: ivar];
                id theirs = [other valueForKey: ivar];
                if (!ours && !theirs) continue;
                if (![ours isEqual: theirs]) return NO;
            }
                
            return YES;
        }
        
        - (id) mutableCopyWithZone:(NSZone *)zone {
            return [self copyWithZone: zone]; /// All instances are mutable.
        }
        
        - (id) copyWithZone: (NSZone *)zone {
            
            id copy = [[self class] new];
        
            for (NSString *ivar in [self ivarNames]) {
                [copy setValue: [self valueForKey: ivar] forKey: ivar];
            }
            
            return copy;
        }
        
        - (void) encodeWithCoder: (NSCoder *)coder {
            for (NSString *ivar in [self ivarNames])
                [coder encodeObject: [self valueForKey: ivar] forKey: ivar];
        }
        
        + (BOOL) supportsSecureCoding { return YES; }
        
        - (instancetype) initWithCoder: (NSCoder *)coder {
            
            if (!(self = [super init])) return nil; /// Pretty sure [NSObject init] does nothing [Nov 2025]
            
            if (!coder.requiresSecureCoding)
                for (NSString *ivar in [self ivarNames])
                    [self setValue: [coder decodeObjectForKey: ivar] forKey: ivar];
            else {
                
                for (NSString *ivar in [self ivarNames]) {
                    
                    Class cls;
                    {
                        #define ret(v) { cls = (v); goto end; }
                        
                        const char *type = ivar_getTypeEncoding(class_getInstanceVariable([self class], ivar.UTF8String));
                        if (strlen(type) == 1 && type[0] == '@')                             ret (nil);              /// Below I say `id` gets encoded as `@""` but currently seeing `@` (M1 MBP, macOS Tahoe, [Nov 2025])
                        if (strlen(type) < 3)                                                ret ([NSValue class]);  /// We're expecting the string to look like `@"<theclassname>"`, if it doesn't follow this pattern, it's not an object and KVC encoded it as an NSValue.
                        if (type[0] != '@' || type[1] != '"' || type[strlen(type)-1] != '"') ret ([NSValue class]);

                        NSString *typeNS = @(type);
                        typeNS = [typeNS substringFromIndex: 2]; /// Cut off `@"`
                        typeNS = [typeNS substringToIndex: [typeNS rangeOfCharacterFromSet: [charset_words() invertedSet]].location]; /// Go up to the first non-word character. This usually will be the last char `"`but can also be `<` if the type encoding contains a protocol conformance. [Nov 2025]
                        ret (NSClassFromString(typeNS)); /// Can be nil if the ivar is declared `id`
                        
                        #undef ret
                    } end:;
                    
                    /// Depending on the `coder.decodingFailurePolicy`, `decodeObjectOfClass:` might either throw and error or just set `coder.error` and then return. Either way we don't have to do anything specific. [Nov 2025]
                    id decoded = [coder decodeObjectOfClass: cls forKey: ivar];
                    
                    [self setValue: decoded forKey: ivar];
                    
                }
                
            }
            
            return self;
        }
@end
