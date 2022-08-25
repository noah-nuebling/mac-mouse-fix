//
//  NSView+Extensions.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 12/31/21.
//

import Foundation

extension NSView {
    
    // MARK: Stored Properties
    ///     Extensions can't store values in swift, so we have to use associated values as a workaround
    ///     Src: https://marcosantadev.com/stored-properties-swift-extensions/
    
    private struct CustomPropertyKeys {
        static var currentAnimationUUID = 1
    }
    private var latestAnimationUUID: UUID {
        get {
            return objc_getAssociatedObject(self, &CustomPropertyKeys.currentAnimationUUID) as! UUID
        }
        set {
            return objc_setAssociatedObject(self, &CustomPropertyKeys.currentAnimationUUID, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    // MARK: Size
    
    @objc func size() -> NSSize {
        /// This is for overriding in `CoolNSTextField` because self.frame.size is wrong for NSTextField
        return frame.size
    }
    
    // MARK: Screenshots
    
    func imageWithoutWindowBackground() -> NSImage? {
        
        /// Declare result
        let result: NSImage?
        
        var ogOpaque: Bool = false
        var ogHasShadow: Bool = false
        var ogBackgroundColor: NSColor = .init()
        var ogTitleBarIsTransparent: Bool = false
        
        if let w = self.window {
            
            /// Store og window values
            ogOpaque = w.isOpaque
            ogHasShadow = w.hasShadow
            ogBackgroundColor = w.backgroundColor
            ogTitleBarIsTransparent = w.titlebarAppearsTransparent
        
            /// Make window invisible
            w.isOpaque = true
            w.hasShadow = false
            w.backgroundColor = .clear
            w.titlebarAppearsTransparent = true
        }
        
        /// Take screenshot
        
        result = self.image()
        
        /// Restore og window values
            
        if let w = self.window {
            
            w.isOpaque = ogOpaque
            w.hasShadow = ogHasShadow
            w.backgroundColor = ogBackgroundColor
            w.titlebarAppearsTransparent = ogTitleBarIsTransparent
        }
        
        /// Return

        return result
        
    }
    
    /// Render view to image
    ///     Src: https://stackoverflow.com/a/41387514/10601702
    ///     EDIT: I feel like this looks worse than the other implementation? Probably placebo
    
    /// Get `NSImage` representation of the view.
    /// - Returns: `NSImage` of view
    
    private func image1() -> NSImage {
        let imageRepresentation = bitmapImageRepForCachingDisplay(in: bounds)!
        cacheDisplay(in: bounds, to: imageRepresentation)
        return NSImage(cgImage: imageRepresentation.cgImage!, size: bounds.size)
    }
    
    /// Attempt 2
    ///     Src: https://developer.apple.com/forums/thread/88315
    
    @objc func image() -> NSImage? {
        /// Note: The name image() collides with NSImageViews image property I think.
        
        let imgSize = bounds.size

        guard let bir = self.bitmapImageRepForCachingDisplay(in: bounds) else {
            return nil
        }
        bir.size = imgSize
        self.cacheDisplay(in: bounds, to: bir)

        let image = NSImage(size: imgSize)
        image.addRepresentation(bir)

        return image
    }
    
    // MARK: Set Anchor Point
    
    /// Stolen from some SO post
    func coolSetAnchorPoint (anchorPoint:CGPoint) {
        if let layer = self.layer {
            var newPoint = CGPoint(x: self.bounds.size.width * anchorPoint.x, y: self.bounds.size.height * anchorPoint.y)
            var oldPoint = CGPoint(x: self.bounds.size.width * layer.anchorPoint.x, y: self.bounds.size.height * layer.anchorPoint.y)

            newPoint = newPoint.applying(layer.affineTransform())
            oldPoint = oldPoint.applying(layer.affineTransform())

            var position = layer.position

            position.x -= oldPoint.x
            position.x += newPoint.x

            position.y -= oldPoint.y
            position.y += newPoint.y

            layer.position = position
            layer.anchorPoint = anchorPoint
        }
    }
    
    // MARK: Scaling

    /// Function for scaling of a view from it's center with an animation
    /// I took the technique found at https://www.advancedswift.com/nsview-animations-guide/ and extended it to work in more cases
    ///     The only restrictions with this technique I found are:
    ///         - Animating the scaling of focus rings doesn't work (something I wanted to do)
    ///         - If I set the UI scaling to small on my 4k display, the animation somehow glitches on NSTextViews and makes it have angled corners instead of rounded ones (something I wanted to do :/)
        
    func scale(withFactor targetScale: CGFloat, animation: CABasicAnimation, onComplete: @escaping () -> ()) {
        /// Wrapper for __scaleView
        
        __scaleView(self, targetScale, animation, onComplete)
    }
    
    func scale(withFactor targetScale: CGFloat, timingFunction: CAMediaTimingFunction, duration: Double, onComplete: @escaping () -> ()) {
        /// Wrapper for __scaleView
        
        let animation = CABasicAnimation()
        animation.timingFunction = timingFunction
        animation.duration = duration
        
        __scaleView(self, targetScale, animation, onComplete)
    }
    
    private func __scaleView(_ view: NSView, _ targetScale: CGFloat, _ scaleAnimation: CABasicAnimation, _ completionCallback: @escaping () -> ()) {

        /// Get current scale
        let currentScaleX = Double(truncating: view.layer?.presentation()?.value(forKeyPath: "transform.scale.x") as! NSNumber)
        let currentScaleY = Double(truncating: view.layer?.presentation()?.value(forKeyPath: "transform.scale.y") as! NSNumber)
        assert(currentScaleX == currentScaleY)
        let currentScale: CGFloat = CGFloat(currentScaleX)
        
        /// Set start and end
        scaleAnimation.fromValue = CATransform3DMakeScale(currentScale, currentScale, 1.0)
        scaleAnimation.toValue = CATransform3DMakeScale(targetScale, targetScale, 1.0)
        
        /// Make the animation not reset the scale after completing
        scaleAnimation.fillMode = .forwards
        scaleAnimation.isRemovedOnCompletion = false

        /// Set anchor point to center
        view.coolSetAnchorPoint(anchorPoint: .init(x: 0.5, y: 0.5))
        
        CATransaction.begin()
        
        /// Setup callback
        ///     Do the UUID stuff to not call callback for interrupted animations
        let thisAnimationUUID = UUID()
        latestAnimationUUID = thisAnimationUUID
        CATransaction.setCompletionBlock {
            if thisAnimationUUID == self.latestAnimationUUID {
                completionCallback()
            }
        }
        /// Add animation to view
        view.layer?.add(scaleAnimation, forKey: "transform")
        
        CATransaction.commit()
    }
    
}
