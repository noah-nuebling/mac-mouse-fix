#import <PreferencePanes/PreferencePanes.h>

@interface PrefPaneDelegate : NSPreferencePane

- (void)mainViewDidLoad;
@property (weak) IBOutlet NSButton *checkbox;

@end
