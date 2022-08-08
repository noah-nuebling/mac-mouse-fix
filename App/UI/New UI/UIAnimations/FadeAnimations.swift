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
    let copiedView = try SharedUtilitySwift.insecureCopy(of: view)
    
    /// Write new newValue
    if let keyPath = keyPath as? String {
        copiedView.setValue(newValue, forKey: keyPath)
    } else { /// I tried using Swift KeyPaths here, but I deleted it to purge the world of this demonic evil
        fatalError()
    }
    /// Replace
    ReplaceAnimations.animate(ogView: view, replaceView: copiedView, hAnchor: .center, vAnchor: .center)
}
