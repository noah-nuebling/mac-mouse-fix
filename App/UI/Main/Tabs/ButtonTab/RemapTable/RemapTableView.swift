//
// --------------------------------------------------------------------------
// RemapTableView.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Cocoa

@objc(RemapTableView)
public class RemapTableView: NSTableView {
    
    @IBOutlet weak var scrollView: MFScrollView?
    @IBOutlet weak var scrollViewMaxHeightConstraint: NSLayoutConstraint?
    
    private var heightConstraint: NSLayoutConstraint?
    
    private var triggerColumWidth: CGFloat = -1
    private var effectColumnWidth: CGFloat = -1
    private var columnConstraints: [NSLayoutConstraint] = []
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.intercellSpacing = NSSize(width: 20, height: 20)
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    @objc public func coolDidLoad() {
        /// Set column widths
        self.updateColumnWidths()
    }
    
    public override func didAdd(_ rowView: NSTableRowView, forRow row: Int) {
        // [Jun 2025] Obsolete setup removed as it caused exceptions on Tahoe Beta
    }
    
    @objc public func updateColumnWidths() {
        #if MF_TEST
        // Column resizing manually for testing
        self.allowsColumnResizing = true
        self.headerView = NSTableHeaderView()
        for column in self.tableColumns {
            column.resizingMask = .userResizingMask
        }
        return
        #endif
        
        /// Delete existing columnConstraints
        if let enclosing = self.enclosingScrollView {
            enclosing.removeConstraints(columnConstraints)
        }
        columnConstraints.removeAll()
        
        let columnPadding: CGFloat = 8.0
        
        for c in 0..<self.numberOfColumns {
            var columnWidth: CGFloat = 0
            
            for r in 0..<self.numberOfRows {
                if let v = self.view(atColumn: c, row: r, makeIfNecessary: true) as? NSTableCellView {
                    columnWidth = max(columnWidth, v.fittingSize.width)
                }
            }
            
            columnWidth += 10
            
            for r in 0..<self.numberOfRows {
                if let v = self.view(atColumn: c, row: r, makeIfNecessary: true) as? NSTableCellView {
                    if v.identifier == NSUserInterfaceItemIdentifier("buttonGroupCell") {
                        continue
                    }
                    let wConstraint = v.widthAnchor.constraint(equalToConstant: columnWidth)
                    wConstraint.priority = .init(999)
                    wConstraint.isActive = true
                }
            }
            
            if c == 0 {
                triggerColumWidth = columnWidth
            } else if c == 1 {
                effectColumnWidth = columnWidth
            } else {
                assertionFailure("Unexpected column index")
            }
        }
        
        if effectColumnWidth < 20 {
            effectColumnWidth = self.frame.size.width / 2.0
        }
        
        let minTableWidth = effectColumnWidth * 2 + 4 * columnPadding
        
        if let enclosing = self.enclosingScrollView {
            let c1 = enclosing.widthAnchor.constraint(greaterThanOrEqualToConstant: minTableWidth)
            c1.priority = .init(999)
            c1.isActive = true
            
            let c2 = enclosing.widthAnchor.constraint(equalToConstant: minTableWidth)
            c2.priority = .init(999)
            c2.isActive = true
            
            columnConstraints.append(c1)
            columnConstraints.append(c2)
        }
        
        let effectColumn = self.tableColumns[1]
        effectColumn.minWidth = effectColumnWidth
        effectColumn.maxWidth = effectColumnWidth
    }
    
    @objc(updateSizeWithAnimation)
    public func updateSizeWithAnimation() {
        self.updateSize(withAnimation: true, tabContentView: nil)
    }
    
    @objc(updateSizeWithAnimation:tabContentView:)
    public func updateSize(withAnimation animate: Bool, tabContentView: NSView?) {
        guard let window = self.window else { return }
        
        let scrollH = self.scrollView?.frame.size.height ?? 0
        let windowH: CGFloat
        if let tabContentView = tabContentView {
            windowH = window.frameRect(forContentRect: tabContentView.frame).size.height
        } else {
            windowH = window.frame.size.height
        }
        let windowHDiff = windowH - scrollH
        let screenH = window.screen?.visibleFrame.size.height ?? 0
        let maxH = min(screenH - windowHDiff, CGFloat.infinity)
        
        self.scrollViewMaxHeightConstraint?.constant = maxH
        
        if heightConstraint == nil {
            heightConstraint = self.heightAnchor.constraint(equalToConstant: 0)
            heightConstraint?.priority = .required
            heightConstraint?.isActive = true
        }
        
        let z = self.intrinsicContentSize
        let newSize = NSSize(width: z.width, height: z.height + 1)
        
        self.setFrameSize(newSize)
        
        if animate {
            NSAnimationContext.runAnimationGroup { context in
                context.timingFunction = CAMediaTimingFunction(name: .default)
                context.duration = 0.25
                heightConstraint?.animator().constant = newSize.height
            }
        } else {
            heightConstraint?.constant = newSize.height
        }
    }
}
