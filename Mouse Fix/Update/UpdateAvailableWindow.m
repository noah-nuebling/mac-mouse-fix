//
//  UpdateAvailableWindow.m
//  Mouse Fix
//
//  Created by Noah Nübling on 28.08.19.
//  Copyright © 2019 Noah Nuebling. All rights reserved.
//

#import "UpdateAvailableWindow.h"
#import <WebKit/WKWebView.h>

@interface UpdateAvailableWindow ()
@property (strong) IBOutlet WKWebView *webView;
@property (weak) IBOutlet NSWindow *window;
@end

@implementation UpdateAvailableWindow

- (void)windowDidLoad {
    [super windowDidLoad];
    
    NSLog(@"UPDATER WINDOW LOADED");
    
    NSURL *url = [NSURL URLWithString: @"http://www.google.com"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [_webView loadRequest:request];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

@end
