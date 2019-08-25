#import <Foundation/Foundation.h>


@interface Utility : NSObject
+ (NSString *)binaryRepresentation:(int)value;
+ (int8_t)signOf:(int64_t)n;
+ (BOOL)sameSign_n:(int64_t)n m:(int64_t)m;
@end

