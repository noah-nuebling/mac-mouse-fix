#import <PreferencePanes/PreferencePanes.h>

@interface PrefPaneDelegate : NSPreferencePane
@property (class, strong) NSView *mainView;
- (void)mainViewDidLoad;
@end
