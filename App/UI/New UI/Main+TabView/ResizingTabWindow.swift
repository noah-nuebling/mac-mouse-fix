//
//  ResizingTabWindow.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 2/11/22.
//

import Cocoa

class ResizingTabWindow: NSWindow {
    
    /// Vars
    public var tabSwitchIsInProgress: Bool = false
    /// ^ This is set by TabViewController
    
    /// Interface for resizing
    func coolSetFrameWithAnimation(_ newFrame: NSRect) {
        /// Src: https://stackoverflow.com/a/6225642/10601702
        /// I think this does the exact same thing as window.setFrame(display:animate:)
        ///     This theoretically allows us to change the animation curve, but easeInOut is already the best looking curve.
        ///     Edit: I just found that this makes the center of the window jitter during resize - which doesn't happen with window.setFrame(display:animate:) -> Don't use this
        
        fatalError("Use `window.setFrame(display:animate:)` instead")
        
        let workload = {
        
            let frameResize: [NSViewAnimation.Key: Any] = [
                .target: self,
                .endFrame: newFrame
            ]
            let animation = NSViewAnimation()
            animation.viewAnimations = [frameResize]
            animation.animationBlockingMode = .blocking /// Not sure what's best here, doesn't seem to make a difference
            animation.animationCurve = .easeInOut
            animation.duration = self.animationResizeTime(newFrame)
            animation.start()
        }
        
        DispatchQueue.main.async { workload() }
    }
    
    override func animationResizeTime(_ newFrame: NSRect) -> TimeInterval {
        
        /// Get size delta
        
        let dWidth = abs(self.frame.width - newFrame.width)
        let dHeight = abs(self.frame.height - newFrame.height)
        
        let dSize = max(dWidth, dHeight)
        
        /// Get position delta
        
        let dx = abs(self.frame.midX - newFrame.midX)
        let dy = abs(self.frame.midY - newFrame.midY)
        
        let dPos = sqrt(dx*dx + dy*dy)
        
        /// Get animation duration for size delta
        ///     Testing:
        ///     Optimal (for transition between general tab and pointer tab):
        ///         disabled (26px): 0.12s
        ///         enabled (114px): 0.20s
        ///         check for updates" enabled (159px): 0.23s
        ///         !updates && acc = macOS (79px): 0.17s
        ///     Fitting Lines: (found using desmos)
        ///         a = 0.82/1000, b = 100/1000
        ///         a = 0.76/1000, b = 110/1000
        
        let tSize = animationDuration(distance: dSize, minDuration: 100/1000, speedUp: 0.82/1000)
        
        /// Get animation duration for position delta
        /// Testing:
        ///     (Edit: I think I might have passed dSize as arg instead of dSize when doing these tests)
        ///     1130px: 700ms
        ///     563px: 400ms (not much testing)
        ///     281px: 275ms (not much testing)
        ///     144px: 225ms (not much testing)
        ///     Fitting line:
        ///         (0.48/1000) x + (155/1000)

        let tPos = animationDuration(distance: dPos, minDuration: 155/1000, speedUp: 0.48/1000)
        
        /// Debug
//        print("Window resize time \(max(tSize, tPos)) dominated by: \(tSize > tPos ? "size change" : "position change") \(tSize>tPos ? dSize : dPos)")
        
        /// Return
        return max(tSize, tPos) /* * 1.1 */
        
    }
    
    /// Other overrides
    
    override func zoom(_ sender: Any?) {
        if tabSwitchIsInProgress { return } /// Prevent zoom during resize
        super.zoom(sender)
    }
}

/// Helper

private func animationDuration(distance: Double, minDuration: TimeInterval = 0.1, speedUp: Double = 0.08) -> TimeInterval {
    
    let result = speedUp * distance + minDuration
    
    return result
}
