//
//  Replace.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 21.06.22.
//

/// Replacing a view with a nice fade animation.
///     Together with Collapse animations, this should allow us to animate any UI state changes we desire

import Foundation
import Cocoa

extension NSView {
    
    /// Interface
    
    func animatedReplace(with view: NSView) {
        
        ReplaceAnimations.animate(ogView: self, replaceView: view, hAnchor: .leading, vAnchor: .center, doAnimate: true)
    }
    
    func unanimatedReplace(with view: NSView) {
        ReplaceAnimations.animate(ogView: self, replaceView: view, hAnchor: .leading, vAnchor: .center, doAnimate: false)
    }
}


class ReplaceAnimations {
    
    /// Storage
    ///     28.08.2024: This seems to be unused.
    private static var _fadeInDelayDispatchQueues: [NSView: DispatchQueue] = [:]
    private static func fadeInDelayDispatchQueue(forView view: NSView) -> DispatchQueue {
        if let cachedQueue = _fadeInDelayDispatchQueues[view] {
            return cachedQueue
        } else {
            let newQueue = DispatchQueue.init(label: "com.nuebling.mac-mouse-fix.fadeInDelay.\(view.hash)", qos: .userInteractive, attributes: [], autoreleaseFrequency: .inherit, target: nil)
            _fadeInDelayDispatchQueues[view] = newQueue
            return newQueue
        }
    }
    
    /// Core function

    @discardableResult static func animate(ogView: NSView, replaceView: NSView, hAnchor: MFHAnchor = .center, vAnchor: MFVAnchor = .center, doAnimate: Bool = true, expectingSizeChanges: Bool = true, onComplete onCompleteArg: @escaping () -> () = { }) -> (() -> ())? {
        
        /// Before you use ReplaceAnimations in any further places:
        /// __! Make this integrate into StackViews !__
        ///     It was a big hassle making this work in AboutTab and TrialNotification having to TrialSectionManager and TrialSection.
        ///     Making this part of StackViews would:
        ///     - Remove the restriction of only one ReplaceAnimation at a time in a group of views that have constraints between each other. That's because we wouldn't have to search and manipulate all the constraints that act on the view that's swapped out, and instead we would only care about our size and the stackViiew would manage the rest.
        ///     - Preventing raceConditions & managing the storage of the views to swap out &  interrupting animations would only have to be solved once and then you could use a simple interface everywhere else.
        
        /// Parameter explanation:
        ///     The animation produces the following changes:
        ///         1. Size change -> The 'feel' is controlled by `animationCurve`
        ///         2. Fade out of `ogView` / Fade in of `replaceView` -> The 'feel' is controlled by `fadeOverlap`
        ///     `duration` controls the duration of all changes that the animation makes
        ///     `hAnchor` and `vAnchor` determine how the ogView and replaceView are aligned with the wrapperView during resizing. If the size doesn't change this doesn't have an effect
        ///     `return` value is a closure that interrupts the animation when invoked. It's nil if doAnimate is false
        
        /// The `replaceView` may have width and height constraints but it shouldn't have any constraints to a superview I think (It will take over the superview constraints from `ogView`)
        
        /// Fadeoverlap should be between -1 and 1
        
        
        /// Validate
        assert(!ogView.translatesAutoresizingMaskIntoConstraints)
        assert(!replaceView.translatesAutoresizingMaskIntoConstraints)
        
        /// Wrap the completionBlock
        ///     So it's only called once, even if it's interrupted first
        
        var hasBeenInvoked = false
        let onComplete = {
            if hasBeenInvoked { return }
            onCompleteArg()
            hasBeenInvoked = true
        }
        
        /// Constants
        
//        let sizeChangeCurve = CAMediaTimingFunction(name: .default)
        
        /// These are lifted from TabViewController
        var fadeOutCurve: CAMediaTimingFunction
//        fadeOutCurve = .init(controlPoints: 0.25, 0.1, 0.25, 1.0) /* default */
//        fadeOutCurve = .init(controlPoints: 0.0, 0.0, 0.25, 1.0)
//        fadeOutCurve = .init(controlPoints: 0.0, 0.5, 0.0, 1.0)
//        fadeOutCurve = .init(controlPoints: 0.0, 0.5, 0.0, 1.0)
        fadeOutCurve = .init(controlPoints: 0.0, 0.5, 0.0, 1.0) /// For new spring animation
        var fadeInCurve: CAMediaTimingFunction
//        fadeInCurve = .init(controlPoints: 0.45, 0, 0.7, 1) /* strong ease in */
//        fadeInCurve = .init(controlPoints: 0.8, 0, 1, 1)
//        fadeInCurve = .init(controlPoints: 0.75, 0.1, 0.75, 1) /* inverted default */
//        fadeInCurve = .init(controlPoints: 0.25, 0.1, 0.25, 1) /* default */
        fadeInCurve = .init(controlPoints: 0.0, 0.0, 0.5, 1.0) /// For new spring animation
        
        
        ///
        /// Store size of ogView
        ///
        
        ogView.superview?.needsLayout = true
        ogView.superview?.layoutSubtreeIfNeeded()
        
        let ogSize = ogView.alignedSize()
        let ogSizeUnaligned = ogView.size()
        
        
        /// Debug
        
        for const in ogView.constraints {
            if const.firstAttribute == .width {
                print("widthConst: \(const), fittingSize: \(ogSize)")
            }
        }
        
        ///
        /// Store image of ogView
        ///
        let ogImage = ogView.takeImage()
        
        ///
        /// Measure replaceView size in layout
        ///
        
        let replaceConstraints = transferredSuperViewConstraints(fromView: ogView, toView: replaceView, transferSizeConstraints: false)
        ogView.superview?.replaceSubview(ogView, with: replaceView)
        for cnst in replaceConstraints {
            cnst.isActive = true
        }
        replaceView.superview?.needsLayout = true
        replaceView.superview?.layoutSubtreeIfNeeded()
        
        let replaceSize = replaceView.alignedSize()
//        let replaceSizeUnaligned = replaceView.size()
        
        ///
        /// Store image of replaceView
        ///
//        let replaceImage = replaceView.takeImage()
        
        ///
        /// Get animationDuration
        ///
        
        let animationDistance = max(abs(replaceSize.width - ogSize.width), abs(replaceSize.height - ogSize.height))
        var duration = getAnimationDuration(animationDistance: animationDistance)
        
        ///
        /// Create `wrapperView` for animating and replace `replaceView`
        ///
        
        /// We replace `replaceView` instead of `ogView` because we've already replaced `ogView` for measuring its size in the layout.
        
        let wrapperView = NoClipWrapper()
        wrapperView.translatesAutoresizingMaskIntoConstraints = false
        wrapperView.wantsLayer = true
        wrapperView.layer?.masksToBounds = false /// Don't think is necessary for NoClipWrapper()
        var wrapperConstraints = transferredSuperViewConstraints(fromView: replaceView, toView: wrapperView, transferSizeConstraints: false)
        let wrapperWidthConst = wrapperView.widthAnchor.constraint(equalToConstant: ogSize.width)
        let wrapperHeightConst = wrapperView.heightAnchor.constraint(equalToConstant: ogSize.height)
        wrapperConstraints.append(wrapperWidthConst)
        wrapperConstraints.append(wrapperHeightConst)
        replaceView.superview?.replaceSubview(replaceView, with: wrapperView)
        for cnst in wrapperConstraints {
            cnst.isActive = true
        }
        
        ///
        /// Create before / after image views for animating
        ///
        /// Edit: I just replaced the replaceImageView with the replaceView. This is better because the replaceView is already responsive to user input during the animation. This seems to work great. I don't know why we were using imageViews to begin with. Maybe we should remove the ogImageView as well. Last commit with the old version: 0219777f8044e854c9b49a1e284ff7cd24d53273
        ///     TODO: Clean this up. Remove the replaceImage and replaceImageView stuff. 
        
        let ogImageView = NSImageView()
        ogImageView.wantsLayer = true
        ogImageView.layer?.masksToBounds = false
        ogImageView.translatesAutoresizingMaskIntoConstraints = false
        ogImageView.imageScaling = .scaleNone
        
        ogImageView.image = ogImage
        ogImageView.widthAnchor.constraint(equalToConstant: ogSizeUnaligned.width).isActive = true
        ogImageView.heightAnchor.constraint(equalToConstant: ogSizeUnaligned.height).isActive = true
        
//        let replaceView = NSImageView()
//        replaceView.wantsLayer = true
//        replaceView.layer?.masksToBounds = false
//        replaceView.translatesAutoresizingMaskIntoConstraints = false
//        replaceView.imageScaling = .scaleNone
//
//        replaceView.image = replaceImage
//        replaceView.widthAnchor.constraint(equalToConstant: replaceSizeUnaligned.width).isActive = true
//        replaceView.heightAnchor.constraint(equalToConstant: replaceSizeUnaligned.height).isActive = true
        
        ///
        /// Add in both imageViews into wrapperView and add constraints
        ///
        
        wrapperView.addSubview(ogImageView)
        wrapperView.addSubview(replaceView)
        
        ///
        /// Add constraints for the 2 imageViews
        ///
        
        /// Get alignmentRect offsets
        
        var hOffsetOG = alignmentOffset(ogView, hAnchor: hAnchor)
        var hOffsetReplace = alignmentOffset(replaceView, hAnchor: hAnchor)
        var vOffsetOG = alignmentOffset(ogView, vAnchor: vAnchor)
        var vOffsetReplace = alignmentOffset(replaceView, vAnchor: vAnchor)
        
        /// Round alignmentRect offsets
        ///     I don't know why this works.
        
        hOffsetOG = round(hOffsetOG)
        hOffsetReplace = round(hOffsetReplace)
        vOffsetOG = round(vOffsetOG)
        vOffsetReplace = round(vOffsetReplace)
        
        /// Create & activate constraints
        
        switch hAnchor {
        case .leading:
            ogImageView.leadingAnchor.constraint(equalTo: wrapperView.leadingAnchor, constant: hOffsetOG).isActive = true
            replaceView.leadingAnchor.constraint(equalTo: wrapperView.leadingAnchor, constant: hOffsetReplace).isActive = true
        case .center:
            ogImageView.centerXAnchor.constraint(equalTo: wrapperView.centerXAnchor, constant: hOffsetOG).isActive = true
            replaceView.centerXAnchor.constraint(equalTo: wrapperView.centerXAnchor, constant: hOffsetReplace).isActive = true
        case .trailing:
            ogImageView.trailingAnchor.constraint(equalTo: wrapperView.trailingAnchor, constant: hOffsetOG).isActive = true
            replaceView.trailingAnchor.constraint(equalTo: wrapperView.trailingAnchor, constant: hOffsetReplace).isActive = true
        }
        switch vAnchor {
        case .top:
            ogImageView.topAnchor.constraint(equalTo: wrapperView.topAnchor, constant: vOffsetOG).isActive = true
            replaceView.topAnchor.constraint(equalTo: wrapperView.topAnchor, constant: vOffsetReplace).isActive = true
        case .center:
            ogImageView.centerYAnchor.constraint(equalTo: wrapperView.centerYAnchor, constant: vOffsetOG).isActive = true
            replaceView.centerYAnchor.constraint(equalTo: wrapperView.centerYAnchor, constant: vOffsetReplace).isActive = true
        case .bottom:
            ogImageView.bottomAnchor.constraint(equalTo: wrapperView.bottomAnchor, constant: vOffsetOG).isActive = true
            replaceView.bottomAnchor.constraint(equalTo: wrapperView.bottomAnchor, constant: vOffsetReplace).isActive = true
        }
        
        ///
        /// Force layout to initial animation state (Probably not necessary)
        ///
        
        wrapperView.superview?.needsLayout = true
        wrapperView.superview?.layoutSubtreeIfNeeded()
        
        ///
        /// Animate size of wrapperView
        ///
        let animation: CAAnimation
        
        if !expectingSizeChanges {
            animation = CABasicAnimation(name: .linear, duration: 0.22)
        } else if doAnimate {
            animation = CASpringAnimation(speed: 3.7, damping: 1.0)
        } else {
            animation = CABasicAnimation(name: .linear, duration: 0.0)
        }
        
        Animate.with(animation, changes: {
            wrapperWidthConst.reactiveAnimator().constant.set(replaceSize.width)
            wrapperHeightConst.reactiveAnimator().constant.set(replaceSize.height)
        }, onComplete: {
            /// Replace wrapper (and imageViews) with replaceView
            wrapperView.superview?.replaceSubview(wrapperView, with: replaceView)
                
            for const in replaceConstraints {
                const.isActive = true
            }
            
            if runningPreRelease() { /// I saw this deadlocking in a release build after resuming from debugger. No idea what's going on.
                DDLogDebug("Finished replacing")
            }
            
            /// Call onComplete
            onComplete()
        })
        
        ///
        /// Animate opacities
        ///
        
        /// Override duration because we're using spring animation now (clean this up)
        duration = 0.22 /*max(animation.duration * 0.55, 0.18)*/
        
        /// Set initial opacities
        ogImageView.alphaValue = 1.0
        replaceView.alphaValue = 0.0
        
        /// Fade out view
        Animate.with(CABasicAnimation(curve: fadeOutCurve, duration: duration)) {
            ogImageView.reactiveAnimator().alphaValue.set(0.0)
        }
        
        /// Fade in view
        Animate.with(CABasicAnimation(curve: fadeInCurve, duration: duration)) {
            replaceView.reactiveAnimator().alphaValue.set(1.0)
        }
        
        /// Return interruptor
        ///     If we need this in more places, maybe we should make this a functionality of reactiveAnimator somehow.
        return !doAnimate ? nil : {
            let manager = NSAnimationManager.current()
            manager?.removeAllAnimations(for: wrapperWidthConst)
            manager?.removeAllAnimations(for: wrapperHeightConst)
            manager?.removeAllAnimations(for: ogImageView)
            manager?.removeAllAnimations(for: replaceView)
            onComplete()
        }
    }
    
    /// Helper
    
    private static func getAnimationDuration(animationDistance: Double) -> CFTimeInterval {
        
        /// This is lifted from Collapse.swift
        
        /// Slow down large animations a little for consistent feel
        let baseDuration = 0.25
        let speed = 180 /// px per second. Duration can be based on this. For some reasons large animations were way too slow with this
        let proportionalDuration = abs(animationDistance) / Double(speed)
        let normalizationFactor = 0.9
        let duration = (1-normalizationFactor) * proportionalDuration + (normalizationFactor) * baseDuration
        
        return duration
    }
    
    /// Alignment offsets
    ///     These functions return the difference between some anchor in a view's frame vs the same anchor in the view's alignmentRect
    
    fileprivate static func alignmentOffset(_ view: NSView, vAnchor: MFVAnchor) -> Double {
        
        /// Get universally useful values
        let h = view.frame.height
        let n = view.alignmentRectInsets
        
        /// Get the offset
        switch vAnchor {
        case .top:
            let alignmentTop = h - n.top
            let frameTop = h
            return alignmentTop - frameTop
        case .center:
            let alignmentCenter = (n.bottom + (h - n.top))/2
            let frameCenter = h/2.0
            return alignmentCenter - frameCenter
        case .bottom:
            let alignmentBottom = n.bottom
            let frameBottom = 0.0
            return alignmentBottom - frameBottom
        }
    }
    
    fileprivate static func alignmentOffset(_ view: NSView, hAnchor: MFHAnchor) -> Double {
        
        /// Get universally useful values
        let w = view.frame.width
        let n = view.alignmentRectInsets
        
        /// Get the offset
        switch hAnchor {
        case .leading:
            let alignmentLeading = n.left /// Note: Is it okay, we're equating left with leading here?
            let frameLeading = 0.0
            return alignmentLeading - frameLeading
        case .center:
            let alignmentCenter = (n.left + (w - n.right))/2
            let frameCenter = w/2.0
            return alignmentCenter - frameCenter
        case .trailing:
            let alignmentTrailing = w - n.right
            let frameTrailing = w
            return alignmentTrailing - frameTrailing
        }
    }
}
