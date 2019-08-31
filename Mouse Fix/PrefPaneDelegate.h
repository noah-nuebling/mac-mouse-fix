#import <PreferencePanes/PreferencePanes.h>

@interface PrefPaneDelegate : NSPreferencePane
- (void)mainViewDidLoad;

- (void)beginSheetPanel;
- (void)endSheetPanel;
@end
