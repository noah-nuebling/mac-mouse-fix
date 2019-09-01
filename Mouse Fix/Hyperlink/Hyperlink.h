#import <Cocoa/Cocoa.h>


@interface Hyperlink : NSTextField
@property (nonatomic) IBInspectable NSString *href;
@property (nonatomic) IBInspectable int linkFrom;
@property (nonatomic) IBInspectable int linkTo;
@end
