//
//  TransitionAnimations.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 26.07.21.
//

import Foundation
import SwiftUI

/// Public

/// Swift-friendly interface
public func fade<P>(on view: NSView,
                       property keyPath: Any,
                       newValue: P) throws {
    
    try doubleFadePropertyChange(view, keyPath, newValue)
}

/// KVC-friendly interface
@objc class FadeAnimations: NSObject {
    
    @objc public static func fade(on view: NSView,
                                  property keyPath: String,
                                  newValue: Any) throws {
        
        try doubleFadePropertyChange(view, keyPath, newValue)
    }
}


private func doubleFadePropertyChange<P>(_ view: NSView,
                                            _ keyPath: Any,
                                            _ newValue: P) throws {
    
    /// Copy view
    let copiedView = try SharedUtilitySwift.insecureDeepCopy(of: view)
    
    /// Write newValue to ogView
    if let keyPath = keyPath as? String {
        view.setValue(newValue, forKeyPath: keyPath)
    } else { /// I tried using Swift KeyPaths here, but I deleted it to purge the world of this demonic evil
        fatalError()
    }
    
    /// Replace view with copiedView
    let copyConstraints = transferredSuperViewConstraints(fromView: view, toView: copiedView, transferSizeConstraints: false)
    view.superview?.replaceSubview(view, with: copiedView)
    for c in copyConstraints {
        c.isActive = true
    }
    
    /// Replace copiedView -> view with animation
    ReplaceAnimations.animate(ogView: copiedView, replaceView: view, hAnchor: .center, vAnchor: .center, doAnimate: true)
}
