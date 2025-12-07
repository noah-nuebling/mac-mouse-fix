//
// --------------------------------------------------------------------------
// AXUIElement_Utils.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "AXUIElement_Utils.h"
#import "SharedUtility.h"
#import "Logging.h"

NSString *AXError_ToString(AXError err) {
    switch (err) {
    case kAXErrorSuccess:                               return @"Success";
    case kAXErrorFailure:                               return @"Failure";
    case kAXErrorIllegalArgument:                       return @"IllegalArgument";
    case kAXErrorInvalidUIElement:                      return @"InvalidUIElement";
    case kAXErrorInvalidUIElementObserver:              return @"InvalidUIElementObserver";
    case kAXErrorCannotComplete:                        return @"CannotComplete";
    case kAXErrorAttributeUnsupported:                  return @"AttributeUnsupported";
    case kAXErrorActionUnsupported:                     return @"ActionUnsupported";
    case kAXErrorNotificationUnsupported:               return @"NotificationUnsupported";
    case kAXErrorNotImplemented:                        return @"NotImplemented";
    case kAXErrorNotificationAlreadyRegistered:         return @"NotificationAlreadyRegistered";
    case kAXErrorNotificationNotRegistered:             return @"NotificationNotRegistered";
    case kAXErrorAPIDisabled:                           return @"APIDisabled";
    case kAXErrorNoValue:                               return @"NoValue";
    case kAXErrorParameterizedAttributeUnsupported:     return @"ParameterizedAttributeUnsupported";
    case kAXErrorNotEnoughPrecision:                    return @"NotEnoughPrecision";
    }
    return stringf(@"(%@)", @(err));
}

NSString *AXUIElement_Description(AXUIElementRef el_arg) {

    /// Written [Dec 2025]
    ///     Haven't we written something like this before?
    
    if (!el_arg) return @"(null)";
    AXUIElementRef el = el_arg;
    
    #define fail(msg...) ({ DDLogDebug(@"Error in AXUIElement_Description: " msg); })
    
    AXError err = 0;
        
    auto actionDict = [NSMutableDictionary new];
    {
        NSArray *names;
        err = AXUIElementCopyActionNames(el, (void *)&names); /// Not sure this `void *` cast is safe with ARC.
        if (err || !names) fail("CopyActionNames failed. Err: %@", AXError_ToString(err));
         
        for (NSString *name in names) {
            
            NSString *value;
            err = AXUIElementCopyActionDescription(el, (__bridge void *)name, (void *)&value); /// Not sure this `void *` cast (And the ones below) is safe with ARC.
            if (err || !value) fail("CopyActionDescription failed. Err: %@", AXError_ToString(err));
            
            [actionDict setObject: value ?: [NSNull null] forKey: name];
         }
     }
     
    auto attrDict = [NSMutableDictionary new];
    {
        NSArray *names;
        err =  AXUIElementCopyAttributeNames(el, (void *)&names);
        if (err || !names) fail("CopyAttributeNames failed. Err: %@", AXError_ToString(err));
         
        for (NSString *name in names) {
            
            id value;
            err = AXUIElementCopyAttributeValue(el, (__bridge void *)name, (void *)&value);
            if (err || !value) fail("CopyAttributeValue failed. Err: %@", AXError_ToString(err));
            
            [attrDict setObject: value ?: [NSNull null] forKey: name];
         }
     }
     
    auto pattrDict = [NSMutableDictionary new];
    {
        NSArray *names;
        err =  AXUIElementCopyParameterizedAttributeNames(el, (void *)&names);
        if (err || !names) fail("CopyParameterizedAttributeNames failed. Err: %@", AXError_ToString(err));
         
        for (NSString *name in names) {
            
            id value;
            CFTypeRef parameter = NULL;
            err = AXUIElementCopyParameterizedAttributeValue(el, (__bridge void *)name, parameter, (void *)&value);
            if (err || !value) fail("CopyParameterizedAttributeValue failed. Err: %@", AXError_ToString(err));
            
            [pattrDict setObject: value ?: [NSNull null] forKey: name];
         }
     }
    
    auto indent = ^NSString *(NSString *s) {
        return [s stringByReplacingOccurrencesOfString: @"(\n)(.)" withString: @"$1    $2" options: NSRegularExpressionSearch range: NSMakeRange(0, s.length)];
    };
    
    return [NSString stringWithFormat: @""
        "AXUIElement (%p) {"
        "\n    Attributes: %@"
        "\n    Actions: %@"
        "\n    Parameterized attributes: %@"
        "\n}"
        ,(void *)el
        ,indent([attrDict description])
        ,indent([actionDict description])
        ,indent([pattrDict description])
    ];
    
}
