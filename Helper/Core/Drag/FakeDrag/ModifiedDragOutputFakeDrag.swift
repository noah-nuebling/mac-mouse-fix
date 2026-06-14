//
// --------------------------------------------------------------------------
// ModifiedDragOutputFakeDrag.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022 (Translated to Swift in 2026)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation
import CoreGraphics

@objc(ModifiedDragOutputFakeDrag)
class ModifiedDragOutputFakeDrag: NSObject, ModifiedDragOutputPlugin {
    
    private weak var drag: ModifiedDragState?
    private var fakeDragButtonNumber: MFMouseButtonNumber = MFMouseButtonNumber(rawValue: 0)
    
    func initialize(with dragState: ModifiedDragState) {
        self.drag = dragState
        
        if let effect = drag?.effectDict,
           let btnNum = effect[kMFModifiedDragDictKeyFakeDragVariantButtonNumber] as? NSNumber {
            self.fakeDragButtonNumber = MFMouseButtonNumber(rawValue: btnNum.uint32Value)
        }
    }
    
    func handleBecameInUse() {
        ModificationUtility.postMouseButton(fakeDragButtonNumber, down: true)
    }
    
    func handleMouseInputWhileInUse(deltaX: Double, deltaY: Double, event: CGEvent?) {
        let location: CGPoint
        if let ev = event {
            location = ev.location
        } else {
            location = getPointerLocation()
        }
        
        let button = SharedUtility.cgMouseButton(from: fakeDragButtonNumber)
        
        // 构造虚拟 otherMouseDragged 事件并发送
        if let draggedEvent = CGEvent(mouseEventSource: nil, mouseType: .otherMouseDragged, mouseCursorPosition: location, mouseButton: button) {
            draggedEvent.post(tap: .cgSessionEventTap)
        }
    }
    
    func handleDeactivationWhileInUse(cancel: Bool) {
        ModificationUtility.postMouseButton(fakeDragButtonNumber, down: false)
    }
    
    func suspend() {}
    func unsuspend() {}
}
