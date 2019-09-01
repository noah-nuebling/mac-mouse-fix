//
//  UpdateWindow.h
//  Mouse Fix
//
//  Created by Noah Nübling on 30.08.19.
//  Copyright © 2019 Noah Nuebling. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UpdateWindow : NSWindowController <NSWindowDelegate, WKNavigationDelegate>
- (void)startWithUpdateNotes:(NSURL *)updateNotesLocation;
@end

NS_ASSUME_NONNULL_END
