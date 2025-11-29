//
//  ModCaptureDeleteButton.swift
//  AnimatingKeyCaptureView
//
//  Created by Noah Nübling on 12/22/21.
//

import Foundation
import Cocoa
import ReactiveSwift

@IBDesignable class ModCaptureDeleteButton: NSButton {
    
    /// Connections
    
    @IBOutlet var parentTextField: ModCaptureTextField?
    
    /// Iinit
    
    override func awakeFromNib() {
        
        parentTextField!.content.flagss.startWithValues { flags in
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.1
                context.timingFunction = .init(name: .default)
                self.animator().alphaValue = flags.isEmpty ? 0 : 1
            }
        }
        
        self.target = parentTextField
        self.action = #selector(ModCaptureTextField.clear(_:))
    }
    
    
    
    override func mouseDown(with event: NSEvent) {
        /// For some reason. self.action is never called, even though we assign it in awakeFromNib, so we have to do this instead. This used to work in the original "mmf-animating-key-capture-view" project. So I have no clue what's going on.
        parentTextField?.clear(self)
    }
    
}
