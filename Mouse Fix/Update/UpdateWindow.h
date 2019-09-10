//
// --------------------------------------------------------------------------
// UpdateWindow.h
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UpdateWindow : NSWindowController <NSWindowDelegate, WKNavigationDelegate>
- (void)startWithUpdateNotes:(NSURL *)updateNotesLocation;
@property (class, strong) UpdateWindow *instance;
@end

NS_ASSUME_NONNULL_END
