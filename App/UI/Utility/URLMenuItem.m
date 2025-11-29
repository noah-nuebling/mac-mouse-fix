//
// --------------------------------------------------------------------------
// URLMenuItem.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "URLMenuItem.h"
#import "Links.h"

/// A menu item which opens a URL when it's clicked. The URL is configurable in Interface Builder

@interface URLMenuItem ()

@property (nonatomic) IBInspectable NSString *MFLinkID; /// This is actually of type MFLinkID, which is an alias for `NSString *`, but IBInspectable requires to literally type `NSString *`.
@property (nonatomic) NSString *URLString;
/// ^ Don't know why this is nonatomic. Copied it from https://stackoverflow.com/questions/24465679/xcode6-ibdesignable-and-ibinspectable-with-objective-c

@end

@implementation URLMenuItem

- (void)awakeFromNib {
    /// Could maybe also use initWithCoder: here

    /// Awake super
    
    [super awakeFromNib];
    
    /// Validate
    assert(_URLString == nil || _URLString.length == 0); /// We're using MFLinkID now.
    
    /// Set action to opening the URL
    
    BOOL enable = self.MFLinkID.length > 0;
    
    [self setEnabled:enable];
    
    if (enable) {
        [self setTarget:self];
        [self setAction:@selector(openURLL:)];
    }
}


- (IBAction)openURLL:(URLMenuItem *)sender {
    
    NSString *link = [Links link:_MFLinkID];
    
    assert(link != nil && link.length > 0);
    
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:link]];
}

@end
