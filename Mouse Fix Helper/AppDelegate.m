#import "AppDelegate.h"
#import "MouseInputReceiver.h"
#import "ModifierInputReceiver.h"
#import "InputParser.h"
#import "ConfigFileInterface.h"
#import "MessagePortReceiver.h"
#import "DeviceManager.h"

#import "MomentumScroll.h"

#import "CGSInternal/CGSHotKeys.h"
#import "SensibleSideButtons/TouchEvents.h"


@interface AppDelegate ()
@property (strong) IBOutlet NSWindow *addedWindow;

@end

@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    NSLog(@"running Mouse Fix Helper");
}
@end
