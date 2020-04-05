//
// --------------------------------------------------------------------------
// UpdateWindow.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "UpdateWindow.h"
#import "Updater.h"
#import "../MoreSheet/MoreSheet.h"
#import "../PrefPaneDelegate.h"
#import <WebKit/WebKit.h>

@interface UpdateWindow ()

@end

@implementation UpdateWindow

// TODO: Make this variable hold the actual UpdateWindow instance instead of the NSWindow instance. The UpdateWindow instance is a window controller and therefore has a _window attribute which holds the same value as this currently does.
static NSWindow *_instance;
+ (NSWindow *)instance {
    return _instance;
}
+ (void)setInstance:(NSWindow *)new {
    _instance = new;
}

- (instancetype)init
{
    NSLog(@"init Update Window");
    self = [super init];
    if (self) {
        UpdateWindow.instance = self;
        self = [self initWithWindowNibName:@"UpdateWindow"];
    }
    return self;
}

- (IBAction)skip:(id)sender {
    [Updater skipAvailableVersion];
    [self close];
}
- (IBAction)update:(id)sender {
    [Updater update];
    [self close];
}

- (void)windowWillClose:(NSNotification *)notification {
    
}

- (void)themeChanged:(NSNotification *)ntf {
    NSLog(@"Theme Changed!");
    [self.window performClose:NULL];
}

- (void)startWithUpdateNotes:(NSURL *)updateNotesLocation {
    [super windowDidLoad];
    
    [NSDistributedNotificationCenter.defaultCenter addObserver:self selector:@selector(themeChanged:) name:@"AppleInterfaceThemeChangedNotification" object: nil];
    
    [super windowDidLoad];
    [self createWebviewWithURL:updateNotesLocation];
    
    
    
    NSRect prefPanewWindowFrame = NSApplication.sharedApplication.mainWindow.frame;
    
    NSPoint prefMid;
    if (NSMidX(prefPanewWindowFrame) == 0 && NSMidY(prefPanewWindowFrame) == 0) {
        NSRect screenMid = NSScreen.mainScreen.frame;
        prefMid = NSMakePoint(NSMidX(screenMid), NSMidY(screenMid)); // fall back of the prefpane window hasn't loaded, yet.
    } else {
        prefMid = NSMakePoint(NSMidX(prefPanewWindowFrame), NSMidY(prefPanewWindowFrame));
    }
    
    
    
    CGSize win = CGSizeMake(330, 220); //(330,[JSreturn floatValue])
    NSRect newWinPos = NSMakeRect(prefMid.x - (win.width/2.0), prefMid.y - (win.height/2.0), win.width, win.height);
//    CGSize dsp = NSScreen.mainScreen.frame.size;
//    NSRect newWinPos = NSMakeRect((dsp.width/2.0) - (win.width/2.0), (dsp.height/2.0) - (win.height/2.0) + 50, win.width, win.height);
    [self.window setFrame:newWinPos display:YES animate:NO];
}

- (void)createWebviewWithURL:(NSURL *)updateNotesURL {
    
//    updateNotesURL = [NSURL fileURLWithPath:@"/Users/Noah/Desktop/updatenotes"];
    
    [self.window setFrame:NSMakeRect(0, 0, 440, 462) display:NO animate:NO];
    NSRect WKFrm = NSMakeRect(80, 57, 340, 363); // (20, 57, 400, 332/363)
    
    
    WKWebViewConfiguration *WKConf = [[WKWebViewConfiguration alloc] init];
    [WKConf.userContentController addScriptMessageHandler:(id<WKScriptMessageHandler>)self name:@"DABIGBUM"];
    
    WKWebView *wv = [[WKWebView alloc] initWithFrame:WKFrm configuration:WKConf];
    [wv setNavigationDelegate:self];
//    [wv setUIDelegate:self];
    

    [wv loadFileURL:[updateNotesURL URLByAppendingPathComponent:@"index.html" isDirectory:NO] allowingReadAccessToURL:updateNotesURL];
    
    wv.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.window.contentView addSubview:wv];

    wv.layer.cornerRadius = 5;
    wv.layer.masksToBounds = YES;

    [wv setValue:@(NO) forKey:@"drawsBackground"];
    [wv display];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSLog(@"FINISCHEDD NAVIGATION");
    
    // change style according to system appearance
    if (@available(macOS 10.14, *)) {
        NSString *cssFileDir = @"Aqua";
        if (NSApplication.sharedApplication.effectiveAppearance == [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]) {
            cssFileDir = @"DarkAqua";
        }
        NSString *jsDir = [NSString stringWithFormat:@"document.getElementById('styleSheetId').href='%@.css'", cssFileDir];
        [webView evaluateJavaScript:jsDir completionHandler:^(id response, NSError *error) {
            NSLog(@"%@",error);
            NSLog(@"%@",(NSString *)response);
        }];
        
        [webView evaluateJavaScript:@"document.getElementsByTagName('h1')[0].textContent" completionHandler:^(id response, NSError *error) {
            NSLog(@"%@",error);
            NSLog(@"%@",(NSString *)response);
        }];
        
//        webView.enclosingScrollView.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];     // I'd like to make the scrollbar dark when darkmode is enabled but this doesn't work
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    
    NSLog(@"%@", navigationAction);
    if (navigationAction.navigationType == -1) {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
    else {
        decisionHandler(WKNavigationActionPolicyCancel);
        [[NSWorkspace sharedWorkspace] openURL:navigationAction.request.URL];
    }
}

@end
