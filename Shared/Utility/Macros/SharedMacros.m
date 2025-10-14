//
//  SharedMacros.m
//  EventLoggerForBrad
//
//  Created by Noah Nübling on 10.02.25.
//

#import "SharedMacros.h"

#pragma mark - mfbox macro

id _mfbox(const void *thing, const char *objc_type) {

    /// Objects (id, Class)
    if (objc_type[0] == '@' || objc_type[0] == '#') {
        return *(id __strong *)thing; /// Is `__strong` correct here? [Oct 2025]
    }
    
    /// Primitives
    #define istype(type) (0 == strcmp(@encode(type), objc_type))
    {
        /// Numbers
        #define boxnum(type, method) \
            if (istype(type)) return [NSNumber method *(type *)thing];
        {
            boxnum(char,                numberWithChar:)
            boxnum(unsigned char,       numberWithUnsignedChar:)
            boxnum(short,               numberWithShort:)
            boxnum(unsigned short,      numberWithUnsignedShort:)
            boxnum(int,                 numberWithInt:)
            boxnum(unsigned int,        numberWithUnsignedInt:)
            boxnum(long,                numberWithLong:)
            boxnum(unsigned long,       numberWithUnsignedLong:)
            boxnum(long long,           numberWithLongLong:)
            boxnum(unsigned long long,  numberWithUnsignedLongLong:)
            boxnum(float,               numberWithFloat:)
            boxnum(double,              numberWithDouble:)
            boxnum(BOOL,                numberWithBool:)
            boxnum(NSInteger,           numberWithInteger:)
            boxnum(NSUInteger,          numberWithUnsignedInteger:)
        }
        #undef boxnum
            
        /// C strings
        if (istype(char *)) return @(*(char **)thing ?: ""); /// nil strings crash when you try to box them IIRC [Oct 2025]

        /// SEL
        if (istype(SEL)) return NSStringFromSelector(*(SEL *)thing);

        /// Fallback - NSValue
        ///     This should also cover all the `objc_boxable`/ `CA_BOXABLE` / `CG_BOXABLE` /  `CF_BOXABLE` types.
        return [NSValue valueWithBytes: thing objCType: objc_type];
    }
    #undef istype
}


#pragma mark - vardesc macro

NSString *_Nullable __vardesc(NSString *_Nonnull keys_commaSeparated, id _Nullable __strong *_Nonnull values, size_t count, bool linebreaks) {
    
    /// Helper for the `vardesc` and `vardescl` macros
    /// Optimization Idea: [Aug 2025] We could optimize by caching the processing of the `keys_commaSeparated` string.
    ///     (This might already be extremely fast – string stuff is usually super fast – This is probably a waste of time! Measure first!)
    ///     To obtain a globally unique cache key per vardesc invocation, we could perhaps use the address of a static var inside the macro as cache key (similar to `dispatch_once`) (Haven't thought this through too much, not sure there are better solutions)
    
    NSMutableArray <NSString *> *keys = [NSMutableArray arrayWithCapacity: count];
    {
        unichar str[keys_commaSeparated.length];
        [keys_commaSeparated getCharacters: str];
        NSUInteger i = 0;
        NSUInteger j = 0;
        int depth = 0;
        
        for (; i < arrcount(str); i++) { /// Split the string by commas, but ignore commas inside brackets.
            
            if (str[i] == '(' || str[i] == '[' || str[i] == '{') { depth++; continue; }
            if (str[i] == ')' || str[i] == ']' || str[i] == '}') { depth--; continue; }
            if (depth < 0) assert(false && "vardesc: Found unbalanced closing bracket"); /// This doesn't catch all cases, but it doesn't matter.
            if (depth > 0) continue;
            
            if (str[i] == ',') {
                NSString *key = [NSString stringWithCharacters: str+j length: i-j];
                [keys addObject: key];
                j = i+1;
            }
        }
        NSString *key = [NSString stringWithCharacters: str+j length: arrcount(str)-j];
        [keys addObject: key];
    }
    
    
    if (count != keys.count) {
        assert(false && "vardesc: Number of keys and values is not equal - This is likely due to one of the passed-in expressions containing a comma.");
        return nil;
    }
    
    NSMutableString *result = [NSMutableString string];
    
    [result appendString: linebreaks ? @"{\n    " : @"{ "];
    for (NSUInteger i = 0; i < count; i++) {
        if (i) [result appendString: linebreaks ? @"\n    " : @" | "];
        [result appendFormat: @"%@ = %@", [keys[i] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]], values[i]];
    }
    [result appendString: linebreaks ? @"\n}" : @" }"];
    
    return result;
}
