//
// --------------------------------------------------------------------------
// NSTextField+Extentions.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation

@objc extension NSTextField {
    
    func coolFittingSize() -> NSSize {
        
        /// `fittingSize` is sometimes *larger* than the explicit height and width constraints. This doesn't make any sense to me and breaks some of my layout code. This function fixes this weird behaviour.
        
        /// Note: Moved this into shared to use with TrialSectionManager but ended up not needing it. Consider moving back to App.
        
        let f = super.fittingSize
        var fittingWidth = f.width
        var fittingHeight = f.height
        
        var widthConst: (width: CGFloat, priority: NSLayoutConstraint.Priority) = (.infinity, .init(-1))
        var heightConst: (height: CGFloat, priority: NSLayoutConstraint.Priority) = (.infinity, .init(-1))
        for const in self.constraints {
            if const.firstAttribute == .width && const.priority > widthConst.priority{
                widthConst = (width: const.constant, priority: const.priority)
            }
            if const.firstAttribute == .height && const.priority > heightConst.priority {
                heightConst = (height: const.constant, priority: const.priority)
            }
        }
        
        if widthConst.width < fittingWidth {
            fittingWidth = widthConst.width
        }
        if heightConst.height < fittingHeight {
            fittingHeight = heightConst.height
        }
        
        return NSSize(width: fittingWidth, height: fittingHeight)
    }
}
