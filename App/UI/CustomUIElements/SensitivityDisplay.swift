//
//  SensitivityDisplay.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 12/30/21.
//

import Cocoa
import ReactiveCocoa
import ReactiveSwift

extension Reactive where Base : SensitivityDisplay {
    var resetValue: Signal<NSNull, Never>{ return base.resetValue }
    var values: Signal<Int, Never> { return base.values }
    var title: BindingTarget<String> { return BindingTarget(object: base, keyPath: "title") }
}

class SensitivityDisplay: NSButton {
    /// A button which displays mouse sensitivity
    /// Can be dragged to change sensitivity
    
    fileprivate var values: Signal<Int, Never>
    private var observer: Signal<Int, Never>.Observer
    
    var resetValue: Signal<NSNull, Never>
    var resetObserver: Signal<NSNull, Never>.Observer
        
    required init?(coder: NSCoder) {
        
        (values, observer) = Signal<Int, Never>.pipe()
        (resetValue, resetObserver) = Signal<NSNull, Never>.pipe()
        
        super.init(coder: coder)
        
        wantsLayer = true /// If we don't set this true, then the textColor will sometimes be wrong until we interact with the view
    }
    
    
    var mouseIsDown: Bool = false
    var mouseDownOrigin: NSPoint = NSPoint()
    var observedDelta: Int = 0
    var dragMonitor: Any? = nil
    override func mouseDown(with event: NSEvent) {
        /// super.mouseDown needs to be blocked for mouseDragged() to be called for some reason
        
        mouseIsDown = true
        observedDelta = 0
        mouseDownOrigin = event.locationInWindow
        dragMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { event in
            if event.type == .leftMouseUp {
                self.coolMouseUp(with: event)
            } else {
                self.coolMouseDragged(with: event)
            }
            return event
        }
    }
    func coolMouseUp(with event: NSEvent) {
        
        NSEvent.removeMonitor(dragMonitor as Any)
        
        if mouseIsDown && observedDelta <= 1 && hitTest(event.locationInWindow) != nil {
            resetObserver.send(value: NSNull())
        }
        mouseIsDown = false
    }
    
    func coolMouseDragged(with event: NSEvent) {
        /// normal mouseDragged() randomly stopped working when moving pointer outside view bounds. Idk what's happening.
        
        let delta = Int(event.deltaY) /// Deltas are always whole numbers
//        print("Delta: \(delta)")
        self.observer.send(value: delta)
        observedDelta += abs(delta)
    }
}

/// Helper

private func distance(_ p1: NSPoint, _ p2: NSPoint) -> Double {
    let dx = p2.x - p1.x
    let dy = p2.y - p1.y
    return sqrt(dx*dx + dy*dy)
}
