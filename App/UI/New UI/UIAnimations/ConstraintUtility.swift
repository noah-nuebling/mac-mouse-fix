//
//  ConstraintUtility.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 22.06.22.
//

import Foundation
import AppKit

func iterateSuperViewConstraintsOn(view: NSView, callback: (NSLayoutConstraint, MFLayoutConstraintIndex) -> ()) {
    
    /// Iterate constraints on `view` that involve a superview
    
    for constraint in view.constraints {
        guard let first = constraint.firstItem as? NSView else { continue }
        guard let second = constraint.secondItem as? NSView? else { continue }
        if first == view, second == view.superview {
            callback(constraint, .firstItem)
        } else if second == view, first == view.superview {
            callback(constraint, .secondItem)
        }
    }
    
    /// Iterate constraints on superviews that involve `view`
    
    var _superview = view.superview
    
    while let superview = _superview {
        for constraint in superview.constraints {
            
            if let first = constraint.firstItem as? NSView, first == view {
                callback(constraint, .firstItem)
            }
            if let second = constraint.secondItem as? NSView, second == view {
                callback(constraint, .secondItem)
            }
        }
        
        _superview = superview.superview
    }
}

func transferSuperViewConstraints(fromView srcView: NSView, toView dstView: NSView, transferSizeConstraints: Bool) -> [NSLayoutConstraint] {

    var srcConstraints: [(NSLayoutConstraint, MFLayoutConstraintIndex)] = []
    iterateSuperViewConstraintsOn(view: srcView, callback: { cnst, srcIndex in
        srcConstraints.append((cnst, srcIndex))
    }) /// Store srcConstraints first before iterating on them so we don't mutate while iterate, changing which objects we iterate. (Not sure if this is really a proplem)
    
    var dstConstraints: [NSLayoutConstraint] = []
    for (cnst, srcIndex) in srcConstraints {
        if !transferSizeConstraints && (cnst.firstAttribute == .width || cnst.firstAttribute == .height) {
            /// I don't understand how `iterateSuperViewConstraintsOn` would ever give back height constraints?
//            assert(false)
            continue
        }
        let newFirst = srcIndex == .firstItem ? dstView : cnst.firstItem
        let newSecond = srcIndex == .secondItem ? dstView : cnst.secondItem
        guard let newFirst = newFirst as? NSView, let newSecond = newSecond as? NSView? else { continue }
        let newConstraint = NSLayoutConstraint(item: newFirst, attribute: cnst.firstAttribute, relatedBy: cnst.relation, toItem: newSecond, attribute: cnst.secondAttribute, multiplier: cnst.multiplier, constant: cnst.constant)
        dstConstraints.append(newConstraint)
        
        if (newFirst == srcView && newSecond == dstView) || (newFirst == dstView && newSecond == srcView) {
            assert(false)
        }
    }
    
    return dstConstraints /// Shouldn't this function just assign the dstConstrains to the dstView instead of returning them?
}

enum MFLayoutConstraintIndex {
    case firstItem
    case secondItem
}
enum MFHAnchor {
    case leading
    case center
    case trailing
}
enum MFVAnchor {
    case top
    case center
    case bottom
}
