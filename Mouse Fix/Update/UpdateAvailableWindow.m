//
//  UpdateAvailableWindow.m
//  Mouse Fix
//
//  Created by Noah Nübling on 28.08.19.
//  Copyright © 2019 Noah Nuebling. All rights reserved.
//

#import "UpdateAvailableWindow.h"
#import <WebKit/WKWebView.h>
#import <WebKit/WKWebViewConfiguration.h>

@interface UpdateAvailableWindow ()
@property (strong) IBOutlet WKWebView *webView;
@property (weak) IBOutlet NSWindow *window;
@end

@implementation UpdateAvailableWindow

- (void)windowWillLoad {
    NSLog(@"UPDATER WINDOW LOADED");
    
    CGRect webViewFrame = CGRectMake(5, 5, 500, 500);
    WKWebViewConfiguration *conf = [WKWebViewConfiguration alloc];
    conf.applicationNameForUserAgent = @"Mac Mouse Fix";
    
    _webView = [_webView initWithFrame:webViewFrame configuration:conf];
    
    NSURL *url = [NSURL URLWithString: @"http://www.google.com"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [_webView loadRequest:request];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

@end
