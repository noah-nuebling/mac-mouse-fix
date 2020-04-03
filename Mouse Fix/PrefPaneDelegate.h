//
// --------------------------------------------------------------------------
// PrefPaneDelegate.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <PreferencePanes/PreferencePanes.h>

@interface PrefPaneDelegate : NSPreferencePane
@property (class, strong) NSView *mainView;
- (void)mainViewDidLoad;
@end
