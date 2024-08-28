//
// --------------------------------------------------------------------------
// MFKeystrokeCaptureView.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "KeyCaptureView.h"
#import "AppDelegate.h"
#import "UIStrings.h"
#import <Carbon/Carbon.h>
#import "MFMessagePort.h"
#import "NSView+Additions.h"
#import "Mac_Mouse_Fix-Swift.h"

@interface KeyCaptureView ()

- (IBAction)backgroundButton:(id)sender;

@end

@implementation KeyCaptureView {
    
    BOOL _isCapturing;
    
    CaptureHandler _captureHandler;
    CancelHandler _cancelHandler;
    
    id _localEventMonitor;
    
    NSDictionary *_attributesFromIB;
}

#pragma mark - (Pseudo) Properties

- (void)setCoolString:(NSString *)string {
    
    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:string attributes:_attributesFromIB];
    
    self.textStorage.attributedString = attributedString;
}

#pragma mark - Setup

- (void)setupWithCaptureHandler:(CaptureHandler)captureHandler
                   cancelHandler:(CancelHandler)cancelHandler {
    
    DDLogDebug(@"Setting up keystroke capture view");
    
    self.delegate = self;
    _captureHandler = captureHandler;
    _cancelHandler = cancelHandler;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [MainAppState.shared.window makeFirstResponder:self];
    });
    // ^ This view is being drawn by the tableView. Using dispatch_async makes it execute after the tableView is done drawing preventing a crash
    
}

#pragma mark - Lifecycle and drawing

- (void)awakeFromNib {
    
    if (_attributesFromIB == nil) {
        _attributesFromIB = [self.attributedString attributesAtIndex:0 effectiveRange:nil];
    }
}

- (void)drawEmptyAppearance { // Not really drawing in the NSFillRect sense, probably a bad name
    
    self.coolString = NSLocalizedString(@"type-shortcut-prompt", @"");
    self.textColor = NSColor.placeholderTextColor;
    
    [self selectAll:nil];
}

- (void)dealloc {
    
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark keyCaptureModeFeedback

+ (void)handleKeyCaptureModeFeedbackWithPayload:(NSDictionary *)payload isSystemDefinedEvent:(BOOL)isSystem {
    
    /// Find keyCaptureField instance in remapsTable
    
    NSTableView *remapsTable = MainAppState.shared.remapTable;
    NSInteger effectColumn = [remapsTable columnWithIdentifier:@"effect"];
    NSMutableIndexSet *indexes = [NSMutableIndexSet new];
    for (int r = 0; r < remapsTable.numberOfRows; r++) {
        NSView *effectView = [MainAppState.shared.remapTable viewAtColumn:effectColumn row:r makeIfNecessary:NO];
        if ([effectView.identifier isEqual:@"keyCaptureCell"]) {
            [indexes addIndex:r];
        }
    }
    assert(indexes.count <= 1);
    if (indexes.count == 0) return;
    
    NSTableCellView *keyCaptureCell = [MainAppState.shared.remapTable viewAtColumn:effectColumn row:indexes.firstIndex makeIfNecessary:NO];
    KeyCaptureView *keyCaptureView = (KeyCaptureView *)[keyCaptureCell nestedSubviewsWithIdentifier:@"keyCaptureView"].firstObject;
    
    /// Send payload to found instance
    
    [keyCaptureView handleKeyCaptureModeFeedbackWithPayload:payload isSystemDefinedEvent:isSystem];
}

- (void)handleKeyCaptureModeFeedbackWithPayload:(NSDictionary *)payload isSystemDefinedEvent:(BOOL)isSystem {
    
    _isCapturing = NO; /// Helper disabled keyCaptureMode after sending payload
    
    CGKeyCode keyCode = USHRT_MAX;
    MFSystemDefinedEventType type = UINT_MAX;
    CGEventFlags flags;
    
    if (isSystem) {
        type = ((NSNumber *)payload[@"systemEventType"]).unsignedIntValue;
        flags = ((NSNumber *)payload[@"flags"]).unsignedLongValue;
    } else {
        keyCode = ((NSNumber *)payload[@"keyCode"]).unsignedShortValue;
        flags = ((NSNumber *)payload[@"flags"]).unsignedLongValue;
    }
    
    [MainAppState.shared.window makeFirstResponder:nil]; /// Important to call this before capture handler, otherwise `resignFirstResponder:` (our teardown function) isn't called
    
    _captureHandler(keyCode, type, flags); /// This should undraw the view
}

#pragma mark FirstResponderStatus handlers

- (BOOL)becomeFirstResponder {
    
    DDLogDebug(@"BECOME FIRST RESPONDER");
    
    BOOL superAccepts = [super becomeFirstResponder];
    
    if (superAccepts) {
        
        _isCapturing = YES;
        
        // If the window goes to the background, resign key
        [NSNotificationCenter.defaultCenter addObserverForName:NSWindowDidResignKeyNotification object:MainAppState.shared.window queue:nil usingBlock:^(NSNotification * _Nonnull note) {
                    [MainAppState.shared.window makeFirstResponder:nil];
        }];
        
        [MFMessagePort sendMessage:@"enableKeyCaptureMode" withPayload:@"" waitForReply:NO];
        /// ^ Do actual capturing in helper app because it already has permissions to stop captured events from being sent to other apps
        
        [self drawEmptyAppearance];
        
        _localEventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:(NSEventMaskFlagsChanged | NSEventMaskKeyDown | NSEventMaskLeftMouseDown) handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
            CGEventRef e = event.CGEvent;
            /// User is playing around with modifier keys
            
            if (event.type == NSEventTypeFlagsChanged) {
                CGEventFlags flags = CGEventGetFlags(e);
                
                NSString *modString = [UIStrings getKeyboardModifierString:flags];
                if (modString.length > 0) {
                    self.coolString = modString;
                } else {
                    [self drawEmptyAppearance];
                }
            } else if (event.type == NSEventTypeKeyDown) {
//                assert(!self->_isCapturing); // _isCapturing should be set to NO by `handleKeyCaptureModeFeedbackWithPayload:` before this is executed.
            } else if (event.type == NSEventTypeLeftMouseDown) {
                /// If the user clicks anything, resign key. -> To prevent weird states. E.g. where Mac Mouse Fix is disabled while the field is still up
                [MainAppState.shared.window makeFirstResponder:nil];
            }
            
            /// Set the `RECORDING_MODE` flag when you want to record video demos, so that cleanshot can properly highlight when a button or keyboard key is pressed. Edit: This doesn't seem to work here.
#if RECORDING_MODE
            return event;
#endif
            return nil;
        }];
    }
    
    return superAccepts;
}
- (BOOL)resignFirstResponder {

    DDLogDebug(@"RESIGN FIRST RESPONDER");
    
    BOOL superResigns = [super resignFirstResponder];

    if (superResigns) {
        
        [MFMessagePort sendMessage:@"disableKeyCaptureMode" withPayload:nil waitForReply:NO];
        [NSEvent removeMonitor:_localEventMonitor];
        _localEventMonitor = nil; /// Otherwise crashes on macOS 10.13 and 10.14. Didn't test other versions.
        _cancelHandler();
    }
    return superResigns;
}

#pragma mark - Disable MouseDown and mouseover cursor

- (void)mouseDown:(NSEvent *)event {
    /// Ignore
}
- (void)mouseMoved:(NSEvent *)event {
    [NSCursor.arrowCursor set]; /// Prevent text insertion cursor from appearing on mouseover
}
- (void)scrollWheel:(NSEvent *)event {
    [NSCursor.arrowCursor set]; /// Prevent text insertion cursor from appearing on scroll
}

- (IBAction)backgroundButton:(id)sender {
}
@end
