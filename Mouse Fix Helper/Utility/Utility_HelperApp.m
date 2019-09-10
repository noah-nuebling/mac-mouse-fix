#import "Utility_HelperApp.h"

@implementation Utility_HelperApp

+ (NSString *)binaryRepresentation:(int)value {
    long nibbleCount = sizeof(value) * 2;
    NSMutableString *bitString = [NSMutableString stringWithCapacity:nibbleCount * 5];
    
    for (long index = 4 * nibbleCount - 1; index >= 0; index--)
    {
        [bitString appendFormat:@"%i", value & (1 << index) ? 1 : 0];
        if (index % 4 == 0)
        {
            [bitString appendString:@" "];
        }
    }
    return bitString;
}

+ (int8_t)signOf:(int64_t)n {
    if (n == 0) {return 0;}
    return n >= 0 ? 1 : -1;
}
+ (BOOL)sameSign_n:(int64_t)n m:(int64_t)m {
    if (n == 0 || m == 0) {
        return true;
    }
    if ([self signOf:n] == [self signOf:m]) {
        return true;
    }
    return false;
}

+ (NSBundle *)helperBundle {
    return [NSBundle bundleForClass:Utility_HelperApp.class];
}
+ (NSBundle *)prefPaneBundle {
    
    NSURL *prefPaneBundleURL = [self helperBundle].bundleURL;
    for (int i = 0; i < 4; i++) {
        prefPaneBundleURL = [prefPaneBundleURL URLByDeletingLastPathComponent];
    }
    NSBundle *prefPaneBundle = [NSBundle bundleWithURL:prefPaneBundleURL];
    
    NSLog(@"prefPaneBundleURL: %@", prefPaneBundleURL);
    NSLog(@"prefPaneBundle: %@", prefPaneBundle);
    
    return prefPaneBundle;
}

@end
