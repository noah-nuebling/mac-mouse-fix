//
//  RHDraggableImageView.m
//
//  Created by Richard Heard on 6/10/2013.
//  Copyright (c) 2013 Richard Heard. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions
//  are met:
//  1. Redistributions of source code must retain the above copyright
//  notice, this list of conditions and the following disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright
//  notice, this list of conditions and the following disclaimer in the
//  documentation and/or other materials provided with the distribution.
//  3. The name of the author may not be used to endorse or promote products
//  derived from this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
//  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
//  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
//  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
//  NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
//  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
//  THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "RHDraggableImageView.h"
#import "NSImageView+RHImageRectAdditions.h"
#import "NSImage+RHImageRepresentationAdditions.h"
#import "RHARCSupport.h"

static const CGFloat RHDraggableImageViewMinimumDragInitiationDistance = 40.0f;

@interface RHDraggableImageView ()

-(void)_rhdiv_sharedInit;

@end

@implementation RHDraggableImageView

@synthesize allowsDragging=_allowsDragging;
@synthesize representedFilename=_representedFilename;
@synthesize representedURL=_representedURL;
@synthesize maximumDragImageEdgeSize=_maximumDragImageEdgeSize;

#pragma mark - init
-(id)initWithFrame:(NSRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        [self _rhdiv_sharedInit];
    }
    return self;
}

-(id)initWithCoder:(NSCoder *)coder{
    self = [super initWithCoder:coder];
    if (self){
        [self _rhdiv_sharedInit];
    }
    return self;
}

-(void)_rhdiv_sharedInit{
    _allowsDragging = YES;
    _maximumDragImageEdgeSize = 400.0;
}

- (void)dealloc{
    arc_release_nil(_mouseDownEvent);
    arc_release_nil(_representedFilename);
    arc_release_nil(_representedURL);
    arc_super_dealloc();
}

#pragma mark - properties
-(void)setRepresentedFilename:(NSString *)representedFilename{
    if (_representedFilename != representedFilename){
        arc_release(_representedFilename);
        _representedFilename = arc_retain(representedFilename);
    }
}

-(NSString*)representedFilename{
    if (_representedFilename) return _representedFilename;
    if (_representedURL) return [_representedURL lastPathComponent];
    
    //default
    return NSLocalizedString(@"DraggedImage.png", @"Default Dragged Image File Name");
}


#pragma mark - mouse handling
-(BOOL)acceptsFirstMouse:(NSEvent *)event{
    //allow dragging from non focused window
    return YES;
}

-(void)mouseDown:(NSEvent*)event{
    _mouseDown = YES;
    _dragInProgress = NO;
    _mouseDownPoint = [self convertPoint:[event locationInWindow] fromView:nil];
    arc_release(_mouseDownEvent);
    _mouseDownEvent = arc_retain(event);
}

-(void)mouseDragged:(NSEvent *)event{
    if (_allowsDragging && _mouseDown && !_dragInProgress && self.image){
        
        NSPoint currentPoint = [self convertPoint:[event locationInWindow] fromView:nil];
        CGFloat distance = RHDistanceBetweenPoints(_mouseDownPoint, currentPoint);
        
        if (distance > RHDraggableImageViewMinimumDragInitiationDistance){
            _dragInProgress = YES;
            
            //This is the magic incantation that allows for both a file promise and other items on the drag pasteboard at the same time.
            
            //create an item without the promise
            NSPasteboardItem *pasteboardItem = arc_autorelease([[NSPasteboardItem alloc] init]);
            [pasteboardItem setDataProvider:self forTypes:[NSArray arrayWithObjects:NSPasteboardTypeTIFF, NSPasteboardTypePNG, NSPasteboardTypePDF, nil]];
            
            //now add the item and then specify the promise via the setPropList:forType: method. (Doing this directly on the item does not work)
            NSPasteboard *dragPasteboard = [NSPasteboard pasteboardWithName:NSDragPboard];
            [dragPasteboard clearContents];
            [dragPasteboard writeObjects:@[pasteboardItem]];
            [dragPasteboard setPropertyList:[NSArray arrayWithObject:NSPasteboardTypePNG] forType:NSFilesPromisePboardType];
            
            //if we have a file url, set that also
            if (_representedURL){                
                [dragPasteboard setString:[_representedURL absoluteString] forType:(NSString*)kUTTypeFileURL];
            }
            
            //call through to the dragImage: method. ( we dont bother passing some args as we have overridden the method and dont use them)
            [self dragImage:nil at:NSZeroPoint offset:NSZeroSize event:_mouseDownEvent pasteboard:dragPasteboard source:self slideBack:YES];
            
            
#if 0
            // --------------------------------------------------------------------------------------------------------------------
            // So that we can include both the file promise and image data on the same drag pasteboard we have to re-create the
            // steps that dragPromisedFilesOfTypes performs internally, rather than using it directly. That is why this code is commented out.
            // See above for currently used code.
            //
            //initiate drag with default PNG icon. (we override dragImage:at:offset:event:pasteboard:source:slideBack: to provide a custom image and origin)
            NSRect iconRect = NSMakeRect(_mouseDownPoint.x - 16.0, _mouseDownPoint.y - 16.0, 32.0, 32.0);
            [self dragPromisedFilesOfTypes:[NSArray arrayWithObject:NSPasteboardTypePNG] fromRect:iconRect source:self slideBack:YES event:_mouseDownEvent];
            // --------------------------------------------------------------------------------------------------------------------
#endif
            
#if 0
            // --------------------------------------------------------------------------------------------------------------------
            // We should be using kPasteboardTypeFileURLPromise, however it does not appear to actually work in a reliable fashion.
            // see: http://git.chromium.org/gitweb/?p=chromium.git;a=commitdiff;h=d52ae61ffb20628f02a131156f81dda5837be1ce
            // see: http://lists.apple.com/archives/cocoa-dev/2012/Feb/msg00706.html
            // see: http://www.openradar.me/14943849
            //
            // drag from rect
            NSRect imageRect = [self imageRect];
            NSRect dragFromRect = NSInsetRect(imageRect, imageRect.size.width * 0.3, imageRect.size.height * 0.3);
            
            //create a pasteboard item
            NSPasteboardItem *pasteboardItem = arc_autorelease([[NSPasteboardItem alloc] init]);
            [pasteboardItem setDataProvider:self forTypes:[NSArray arrayWithObjects:(NSString *)kPasteboardTypeFileURLPromise, (NSString *)kPasteboardTypeFilePromiseContent, NSPasteboardTypeTIFF, NSPasteboardTypePNG, NSPasteboardTypePDF, nil]];
            NSDraggingItem *dragItem = arc_autorelease([[NSDraggingItem alloc] initWithPasteboardWriter:pasteboardItem]);
            [dragItem setDraggingFrame:dragFromRect contents:[self image]];
            
            NSDraggingSession *session = [self beginDraggingSessionWithItems:[NSArray arrayWithObject:dragItem] event:event source:self];
            session.animatesToStartingPositionsOnCancelOrFail = YES;
            session.draggingFormation = NSDraggingFormationNone;
            // --------------------------------------------------------------------------------------------------------------------
#endif
        }
        
    }
}

-(void)mouseUp:(NSEvent *)event{
    _mouseDownPoint = NSZeroPoint;
    _mouseDown = NO;
    _dragInProgress = NO;
}


#pragma mark - drag handling
-(void)dragImage:(NSImage *)anImage at:(NSPoint)viewLocation offset:(NSSize)initialOffset event:(NSEvent *)event pasteboard:(NSPasteboard *)pboard source:(id)sourceObj slideBack:(BOOL)slideFlag{
    NSRect imageRect = [self imageRect];
    NSRect dragFromRect = imageRect;
    if (imageRect.size.width > _maximumDragImageEdgeSize || imageRect.size.height > _maximumDragImageEdgeSize){
        if (imageRect.size.width > imageRect.size.height){
            double ratio = imageRect.size.height / imageRect.size.width;
            dragFromRect.size.width = _maximumDragImageEdgeSize;
            dragFromRect.size.height = _maximumDragImageEdgeSize * ratio;
        } else {
            double ratio = imageRect.size.width / imageRect.size.height;
            dragFromRect.size.height = _maximumDragImageEdgeSize;
            dragFromRect.size.width = _maximumDragImageEdgeSize * ratio;
        }
        
        //reset the origin so that the smaller image is under our mouse cursor, with the same relative part of the image under the mouse
        CGFloat differenceX = imageRect.size.width - dragFromRect.size.width;
        CGFloat differenceY = imageRect.size.height - dragFromRect.size.height;
        
        double percentageX = MIN(MAX((_mouseDownPoint.x - imageRect.origin.x) / imageRect.size.width, 0.0), 1.0);
        double percentageY = MIN(MAX((_mouseDownPoint.y - imageRect.origin.y) / imageRect.size.height, 0.0), 1.0);
        
        dragFromRect.origin.x = imageRect.origin.x + (percentageX * differenceX);
        dragFromRect.origin.y = imageRect.origin.y + (percentageY * differenceY);
    }
    
    //create a new semi-transparent drag image
    NSImage* dragImage = arc_autorelease([[NSImage alloc] initWithSize:dragFromRect.size]);
    [dragImage lockFocus];
    [self.image drawInRect:NSMakeRect(0.0, 0.0, dragImage.size.width, dragImage.size.height) fromRect:NSZeroRect operation:NSCompositeDestinationOver fraction:0.7f];
    [dragImage unlockFocus];
    [dragImage setSize:dragFromRect.size];
    
    [super dragImage:dragImage at:dragFromRect.origin offset:NSZeroSize event:event pasteboard:pboard source:sourceObj slideBack:slideFlag];
}

-(NSArray *)namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination{
    if (_representedURL){
        NSError *error = nil;
        NSURL *destination = [dropDestination  URLByAppendingPathComponent:self.representedFilename isDirectory:NO];
        if (![[NSFileManager defaultManager] copyItemAtURL:_representedURL toURL:destination error:&error]){
            NSLog(@"Error: Drag failed to copy file from:%@ to %@ with error: %@", _representedURL, destination, error);
        }
    } else {
        [[self.image PNGRepresentation] writeToFile:[[dropDestination path] stringByAppendingPathComponent:self.representedFilename]  atomically:YES];
    }
    return [NSArray arrayWithObject:self.representedFilename];
}


#pragma mark - NSDraggingSource
-(NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context{
    //we only support copy, for all locations
    return NSDragOperationCopy;
}

- (void)draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint{
    //stash
    _currentDraggingSequenceNumber = session.draggingSequenceNumber;
}


#pragma mark - NSDraggingDestination
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender{
    //if sender is our own drag, refuse
    if ([sender draggingSequenceNumber] == _currentDraggingSequenceNumber){
        return NO;
    }
    
    //otherwise pass to super, if implemented otherwise return yes
    if ([[NSImageView class] instancesRespondToSelector:@selector(prepareForDragOperation:)]){
        return [super prepareForDragOperation:sender];
    } else {
        return YES;
    }
}


#pragma mark - NSPasteboardItemDataProvider
-(void)pasteboard:(NSPasteboard *)sender item:(NSPasteboardItem *)item provideDataForType:(NSString *)type{
    //drag was accepted, send data as promised.
    if ([type isEqualToString:NSPasteboardTypeTIFF]) {
        [sender setData:[[self image] TIFFRepresentation] forType:NSPasteboardTypeTIFF];
    } else if ([type isEqualToString:NSPasteboardTypePNG]) {
        [sender setData:[[self image] PNGRepresentation] forType:NSPasteboardTypePNG];
    } else if ([type isEqualToString:NSPasteboardTypePDF]) {
        [sender setData:[self dataWithPDFInsideRect:[self imageRect]] forType:NSPasteboardTypePDF];
    }
    
#if 0
    // --------------------------------------------------------------------------------------------------------------------
    // We should be using kPasteboardTypeFileURLPromise, however it does not appear to actually work in a reliable fashion.
    else if ([type isEqualToString:(NSString*)kPasteboardTypeFileURLPromise]) {
        //read the paste location from PasteboardCopyPasteLocation() which is a carbon call.
        NSString *destination = nil; //TODO:
        if (destination) {
            [[[self image] PNGRepresentation] writeToFile:destination atomically:YES];
            // And set some data, to force the change count to update
            [sender setData:[NSData data] forType:type];
        }
    } else if ([type isEqualToString:(NSString*)kPasteboardTypeFilePromiseContent]) {
        [sender setString:(NSString*)kUTTypePNG forType:type];
    }
    // --------------------------------------------------------------------------------------------------------------------
#endif
    
}

@end

CGFloat RHDistanceBetweenPoints(NSPoint p1, NSPoint p2){
    CGFloat distanceX = p1.x - p2.x;
    CGFloat distanceY = p1.y - p2.y;
    return (CGFloat)sqrt(distanceX*distanceX + distanceY*distanceY);
}


