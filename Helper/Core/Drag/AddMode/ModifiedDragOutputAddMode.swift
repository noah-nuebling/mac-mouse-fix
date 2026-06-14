//
// --------------------------------------------------------------------------
// ModifiedDragOutputAddMode.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022 (Translated to Swift in 2026)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation
import CoreGraphics

@objc(ModifiedDragOutputAddMode)
class ModifiedDragOutputAddMode: NSObject, ModifiedDragOutputPlugin {
    
    private weak var drag: ModifiedDragState?
    private var addModePayload: [AnyHashable: Any]?
    private var didConclude: Bool = false
    
    func initialize(with dragState: ModifiedDragState) {
        self.drag = dragState
        self.didConclude = false
        
        if let effect = drag?.effectDict {
            var payload = effect
            payload.removeValue(forKey: kMFModifiedDragDictKeyType)
            self.addModePayload = payload
        }
    }
    
    func handleBecameInUse() {}
    
    func handleMouseInputWhileInUse(deltaX: Double, deltaY: Double, event: CGEvent?) {
        if !didConclude {
            if let payload = addModePayload {
                Remap.sendAddModeFeedback(payload as NSDictionary)
                didConclude = true
            } else {
                fatalError("InvalidAddModeFeedbackPayload: _drag.addModePayload is nil.")
            }
        }
    }
    
    func handleDeactivationWhileInUse(cancel: Bool) {}
    func suspend() {}
    func unsuspend() {}
}
