//
// --------------------------------------------------------------------------
// NSData+Additions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "NSData+Additions.h"
#import "SharedUtility.h"

@implementation NSData (Additions)

- (NSString *)hexString {
    
    const uint8_t *bytes = self.bytes;
    long nBytes = self.length;
    
    NSMutableString *result = [NSMutableString stringWithCapacity:nBytes*2];
    for (int i = 0; i < nBytes; i++) {
        [result appendFormat:@"%02X", bytes[i]];
    }
    
    return result;
}

- (NSString *)description {
    
    /// Globally override the description
    ///     (Hope this won't lead to unforseed consequences.)
    ///
    /// This representation corresponds exactly to how the NSData would be displayed by Xcode when inspecting a .plist file.
    /// Comparison:
    ///     Default description: `{length = 32, bytes = 0xca9e4fd5 4e8e39d8 6120147b 52ee87e3 ... 67b05fa9 c2badf18 }`
    ///     Custom description: `<CA9E4FD54E8E39D86120147B52EE87E36B697DD767F8B1F267B05FA9C2BADF18>`
    
    return stringf(@"<%@>", [self hexString]);
}

@end
