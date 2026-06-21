//
// --------------------------------------------------------------------------
// RemapTableCellView.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "RemapTableCellView.h"
#import "Logging.h"

@implementation RemapTableCellView

    #if 0
        - (void) setFrame: (NSRect)frame {
            DDLogDebug(@"wrapdbg: setFrame: (%p) %@", self, NSStringFromRect(frame));
            [super setFrame: frame];
        }
    #endif
    
    //let columnPadding = 8.0; /// IDK what this was used for. TODO: Delete all this stuff. [Dec 2025]
    
    - (void) coolInitAsTriggerCellWithColumnWidth: (double)columnWidth; {
            
        #if 0
        
            /// TODO: We should really move this to RemapTableView where it is called. It's super tighly coupled and only used in one place.
            
            /// Make it use autolayout.
            ///     We could also do this without subclassing
            
            self.translatesAutoresizingMaskIntoConstraints = false
            
            /// Add in superview constraints
            ///     Tried to add these in IB like the other constraints but I couldn't find a way
            ///     The superview is the rowView, so we don't want to attach to the trailing edge
            
            self.trailingAnchor.constraint(equalTo: self.superview!.trailingAnchor, constant: -columnPadding).isActive = false
            
            self.leadingAnchor.constraint(equalTo: self.superview!.leadingAnchor, constant: columnPadding).isActive = true
            self.topAnchor.constraint(equalTo: self.superview!.topAnchor).isActive = true
            self.bottomAnchor.constraint(equalTo: self.superview!.bottomAnchor).isActive = true
            
            /// Add in width constraint
            ///     priority 999 because otherwise weird 'NSView-Encapsulated-Layout-Width' constraint added by the tableView will break the layout
            if (columnWidth != -1) {
                let c = self.widthAnchor.constraint(equalToConstant: columnWidth)
                c.priority = .init(999)
                c.isActive = true
            }
        #endif
    }
    
    - (void) coolInitAsEffectCellWithColumnWidth: (double)columnWidth; {
        
        #if 0
        
            /// Make it use autolayout.
            ///     Could do this without subclassing
            
            /// Edit: We turned off the trailingConstraint because it was interfering with the rowViews autoresizingMask constraints - and it still looks the same!
            ///     So this stuff is like not even really active I think? Just don't touch it. It works.
            
            self.translatesAutoresizingMaskIntoConstraints = false
            
            /// Superview is rowView so we don't want to attach the leading edge
            
            self.leadingAnchor.constraint(equalTo: self.superview!.leadingAnchor, constant: columnPadding).isActive = false
            
            //self.trailingAnchor.constraint(equalTo: self.superview!.trailingAnchor, constant: -columnPadding).isActive = true
            self.topAnchor.constraint(equalTo: self.superview!.topAnchor).isActive = true
            self.bottomAnchor.constraint(equalTo: self.superview!.bottomAnchor).isActive = true
            
            if (columnWidth != -1) {
                let c = self.widthAnchor.constraint(equalToConstant: columnWidth)
                c.priority = .init(999)
                c.isActive = true
            }
        #endif
    }
@end
