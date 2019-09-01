#import "AppDelegate.h"
#import "MouseInputReceiver.h"
#import "ModifierInputReceiver.h"
#import "InputParser.h"
#import "ConfigFileInterface.h"
#import "DeviceManager.h"


@interface AppDelegate ()
@property (strong) IBOutlet NSWindow *addedWindow;

@end

@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    NSLog(@"running Mouse Fix Helper");
}
@end
