//
// --------------------------------------------------------------------------
// PrefPaneDelegate.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <PreferencePanes/PreferencePanes.h>
#import "MoreSheet/MoreSheet.h"
#import "ScrollOverridePanel.h"

@interface PrefPaneDelegate : NSPreferencePane
@property (class, strong) NSView *mainView;
- (void)mainViewDidLoad;
@property (class, strong) MoreSheet *moreSheetController;
@property (class, strong) ScrollOverridePanel *scrollOverridePanelController;
@end
