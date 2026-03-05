//
// --------------------------------------------------------------------------
// vardesc.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "vardesc.h"
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

#define countof(x...) (sizeof(x) / sizeof((x)[0]))
#define auto __auto_type
#define range(i, count) (int i = 0; i < (count); i++)
#define stringf(x...) ([NSString stringWithFormat: x])
NSString *indented(NSString *s) { return [s stringByReplacingOccurrencesOfString: @"(^|\n)(.)" withString:@"$1    $2" options: NSRegularExpressionSearch range: NSMakeRange(0, s.length)]; }

id __mfbox(void *thing, char *type) {
    
    char *ogtype = type;
    
    char modifiers[] = { _C_COMPLEX, _C_ATOMIC, _C_CONST, _C_IN, _C_INOUT, _C_OUT, _C_BYCOPY, _C_BYREF, _C_ONEWAY, _C_GNUREGISTER };
    again: for range(m, countof(modifiers)) if (modifiers[m] == *type) { type++; goto again; } /// Skip the modifiers in the type-encoding. Not totally sure this is necessary [Mar 4 2026]
    
    if (*type == _C_ID)          return *(id __strong *)thing; /// Is `__strong` right to use here? [Mar 4 2026]
    if (*type == _C_CLASS)       return *(Class *)thing;
    if (*type == _C_SEL)         return NSStringFromSelector(*(SEL *)thing);
    if (*type == _C_CHR)         return [NSNumber numberWithChar: *(char *)thing];
    if (*type == _C_UCHR)        return [NSNumber numberWithUnsignedChar: *(unsigned char *)thing];
    if (*type == _C_SHT)         return [NSNumber numberWithShort: *(short *)thing];
    if (*type == _C_USHT)        return [NSNumber numberWithUnsignedShort: *(unsigned short *)thing];
    if (*type == _C_INT)         return [NSNumber numberWithInt: *(int *)thing];
    if (*type == _C_UINT)        return [NSNumber numberWithUnsignedInt: *(unsigned int *)thing];
    if (*type == _C_LNG)         return [NSNumber numberWithLong: *(long *)thing];
    if (*type == _C_ULNG)        return [NSNumber numberWithUnsignedLong: *(unsigned long *)thing];
    if (*type == _C_LNG_LNG)     return [NSNumber numberWithLongLong: *(long long *)thing];
    if (*type == _C_ULNG_LNG)    return [NSNumber numberWithUnsignedLongLong: *(unsigned long long *)thing];
    if (*type == _C_FLT)         return [NSNumber numberWithFloat: *(float *)thing];
    if (*type == _C_DBL)         return [NSNumber numberWithDouble: *(double *)thing];
    if (*type == _C_BOOL)        return [NSNumber numberWithBool: *(BOOL *)thing];
    if (*type == _C_PTR)         return [NSValue valueWithPointer: *(void **)thing];
    if (*type == _C_CHARPTR)     return [NSString stringWithUTF8String: (*(char **)thing ?: "")]; /// nil strings crash when you try to box them [Mar 4 2026]
    /*fallback*/                 return [NSValue valueWithBytes: thing objCType: ogtype];
}

NSString * _vardesc(NSString *__strong *keys, id __strong * objects, int count) {
    if (count == 0)
        return stringf(@"{}");
    else if (count == 1)
        return stringf(@"{ %@ = %@; }", keys[0], objects[0]);
    else {
        auto result = [NSMutableString string];
        
        [result appendString: @"{\n"];
        for range(i, count) [result appendString: indented(stringf(@"%@ = %@;\n", keys[i], objects[i]))];
        [result appendString: @"}"];
        
        return result;
    }
}
