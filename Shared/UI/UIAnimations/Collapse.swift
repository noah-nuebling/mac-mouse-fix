//
//  Collapse.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 16.06.22.
//

/// Embed views in a `CollapsingStackView` to show and hide them with a nice animation using the `.reactive.isCollapsed` binding target.

/// ISSUE: Sometimes the uncollapse animation on the general tab when enabling the app is broken.
///     \discussion: Investigation shows that this occurs when the preceding collapse of the view has either taken too long or too little time. This actually happens in the edge case where the app is disabled through the trial notification while the general tab is not visible, and then the user switches to the general tab and enables the app again. In this case the preceding collapse has a duration of 0 seconds, because the view was not visible when the collapse was triggered, so the uncollapse animation is broken. I have no clue what may be causing this at the moment.
///     The thing that's going wrong is that there seems to be a clipping layer animated above the enable switch and the "Enable Mac Mouse Fix" label. But this clipping layer doesn't show up when enabling "Show View Frames" and "Show Alignment Rectangles" under View Debugging. Also the problem disappears when we make the __uncollapse__ animation slower. So I don't know how to investigate this further. Maybe if we could pause the animation mid way through and then investigate the view hierarchy.
///     Edit: This now (commit 3735ae46e3ad5e1c5e62fe31749e86f38137448e) seems to always occur when switching the general tab while it's disabled and then enabling it. I don't think this used to be a problem. Not sure when it started occuring.


import Foundation
import ReactiveSwift
import QuartzCore
import AppKit

// MARK: - Helper stuff

class NoClippingLayer: CALayer {
    
    override var masksToBounds: Bool {
        set { }
        get { return false }
    }
}

// MARK: Helper class (WrapperView)

public class NoClipWrapper: NSView {
    
    /// Wrap view
    var wrappedView: NSView {
        return self.subviews[0]
    }
    
    /// Turn off clipping
    public override func makeBackingLayer() -> CALayer { NoClippingLayer() } /// Disable clipping subviews
    
    /// Make alignmentRectInsets settable
    var coolAlignmentRectInsets = NSEdgeInsetsZero
    override public var alignmentRectInsets: NSEdgeInsets {
        return coolAlignmentRectInsets
    }
}

// MARK: - Convenience Interface

private struct AssociatedKeysForReactive {
    static var collapseIsInitialized = 1
}
extension Reactive where Base : NSView {
    
    /// ReactiveSwift hook
    
    var isCollapsed: BindingTarget<Bool> {
        return BindingTarget(lifetime: base.reactive.lifetime) { shouldCollapse in
            
            /// Don't play animation under certain conditions
            /// - Don't play it the first time. This is so that when this is bound to a UI toggle, the initial value doesn't cause an animation.
            /// - Don't play if invisible. This is to prevent issues when the app is disabled while the user is on a different tab. And I guess for efficiency.
            let inited = objc_getAssociatedObject(base, &AssociatedKeysForReactive.collapseIsInitialized) as? Bool ?? false
            let visible = base.window != nil
            
            if !inited || !visible {
                base.setCollapsedWithoutAnimation(shouldCollapse)
                objc_setAssociatedObject(base, &AssociatedKeysForReactive.collapseIsInitialized, true, .OBJC_ASSOCIATION_RETAIN)
            } else {
                base.isCollapsed = shouldCollapse
            }
        }
    }
}

extension NSView {
    
    /// Stored property workaround
    /// Source: https://marcosantadev.com/stored-properties-swift-extensions/
    
    private struct AssociatedKeys {
        static var isCollapsed = 1
    }
    private var _isCollapsed: Bool? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.isCollapsed) as? Bool
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.isCollapsed, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    /// Main Interface
    
    @objc @IBInspectable var isCollapsed: Bool {
        get {
            return self._isCollapsed ?? false
        }
        set {
            setCollapsed(newValue, animate: true)
        }
    }
    @objc func setCollapsedWithoutAnimation(_ collapse: Bool) {
        setCollapsed(collapse, animate: false)
    }
    
    private func setCollapsed(_ collapse: Bool, animate: Bool) {
        
        if self._isCollapsed == collapse { return }
        
        let stack: CollapsingStackView
        if let s = self.superview as? CollapsingStackView {
            stack = s
        } else if let s = self.superview?.superview as? CollapsingStackView { /// Take wrapper into acount
            stack = s
        } else {
            fatalError()
        }
        
        stack.collapseSubView(self, collapse: collapse, animate: animate)
        
        self._isCollapsed = collapse
    }
}

// MARK: - Core (CollapsingStackView)

class CollapsingStackView: NSStackView {
    
    // MARK: Superclass overrides
    
    /// Turn off clipping
    
    override func makeBackingLayer() -> CALayer { NoClippingLayer() }
    
    /// Override superclass interface to work around wrapped views
    
    override var arrangedSubviews: [NSView] {
        
        var result: [NSView] = []
        
        for view in super.arrangedSubviews {
            if let wrapper = view as? NoClipWrapper {
                result.append(wrapper.wrappedView)
            } else {
                result.append(view)
            }
        }
        
        return result
    }
    
    override func removeArrangedSubview(_ view: NSView) {
        
        let rawView: NSView
        
        if let wrapper = view as? NoClipWrapper {
            rawView = wrapper.wrappedView
        } else {
            rawView = view
        }
        
        super.removeArrangedSubview(rawView)
    }
    
    // MARK: Store subview state
    ///     Store additional state for the arrangedSubViews
    
    private func arrangedSubViewState(forView v: NSView) -> ArrangedSubViewState {
        
        if let state = _arrangedSubViewStateStorage[v] {
            return state
        } else {
            let newState = ArrangedSubViewState()
            _arrangedSubViewStateStorage[v] = newState
            return newState
        }
    }
    
    private class ArrangedSubViewState {
        
        var isCollapsable: Bool = false
        
        var bottomConstraint: NSLayoutConstraint?
        var wrapperHeightConstraint: NSLayoutConstraint?
        
        var uncollapseTimer: Timer?
    }
    
    private var _arrangedSubViewStateStorage: [NSView: ArrangedSubViewState] = [:] /// Don't use directly
    
    // MARK: Interface
    
    @objc func collapseSubView(_ v: NSView, collapse: Bool, animate: Bool) {
        
        /// Validate that v is subview
        assert(arrangedSubviews.contains(v))
        
        /// Debug
        
        DDLogDebug("\(collapse ? "Collapsing" : "Uncollapsing") view: \(v). Animate: \(animate)")
        
        /// Constants
                   
        let nullAnimation = CABasicAnimation(name: .linear, duration: 0.0)
        
        /// Init
        v.wantsLayer = true /// Not sure if necessary
        v.translatesAutoresizingMaskIntoConstraints = false /// Not sure if necessary
        
        /// Make collapsable
        makeArrangedSubviewCollapsable(v)
        
        /// Get wrap
        let wrapper = getWrap(forArrangedSubview: v)
        
        /// Get state
        let state = arrangedSubViewState(forView: v)
        
        /// Get height Carlo
        
        /// Get current height
        let currentHeight: CGFloat = wrapper.frame.height
        
        /// Get targetHeight
        let targetHeight: CGFloat
        
        if collapse {
            targetHeight = 0.0
        } else {
            targetHeight = getFullHeight(wrapper, state: state)
        }
        
        /// Get animation
        
        let animation: CABasicAnimation
        
        if !animate {
            animation = nullAnimation
        } else {
            if collapse {
                animation = CASpringAnimation(speed: 4.25, damping: 1.0)
            } else {
                animation = CASpringAnimation(speed: 3.75, damping: 1.0)
            }
        }
        
        /// Get animation duration
        ///     Only using the old getAnimationDuration() func for fade animations now because we're using spring animations now.
        let duration = animation.duration
        let fadeDuration = animate ? getAnimationDuration(animationDistance: targetHeight - currentHeight) : 0.0
         
        /// Invalidate animation timer
        
        state.uncollapseTimer?.invalidate()
        
        if collapse {
            
            /// Add height constraint for wrapper
            ///     We'll animate this
            state.wrapperHeightConstraint!.constant = currentHeight
            state.wrapperHeightConstraint!.isActive = true
            
            /// Remove bottom constraint between wrapper and it's subview
            ///     So the wrapper cuts off the bottom of it's subview during animation
            state.bottomConstraint!.isActive = false
            
            /// Animate height of wrapper
            Animate.with(animation) {
                state.wrapperHeightConstraint?.reactiveAnimator().constant.set(targetHeight)
            }

            /// Animate opacity
            Animate.with(CABasicAnimation(curve: collapseAlphaCurve, duration: fadeDuration)) {
                wrapper.reactiveAnimator().alphaValue.set(0.0)
            }
            
        } else if !collapse { /// Basically do same thing as `collapse` code just in reverse
            
            /// Animate height of wrapper
            // let animationFromConstraint = state.wrapperHeightConstraint?.animation(forKey: "constant") as! CAAnimation /// This one doesn't jitter!! - I investigated what the difference might be in `InvestigateLayoutAnimations.xcproj`, but I couldn't find anything besides `roundsToInteger`. (which does make things better but not entirely) Very mysterious.
            Animate.with(animation) {
                state.wrapperHeightConstraint!.reactiveAnimator().constant.set(targetHeight)
            }
            
            /// Animate opacity
            Animate.with(CABasicAnimation(curve: expandAlphaCurve, duration: fadeDuration)) {
                wrapper.reactiveAnimator().alphaValue.set(1.0)
            }
            
            /// Wait until animation done
            state.uncollapseTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { timer in
                
                /// Add bottom constraint between wrapper and subview back in
                state.bottomConstraint!.isActive = true
                
                /// Remove height constraint for wrapper
                state.wrapperHeightConstraint!.isActive = false
            }

        }
        
    }
    
    // MARK: Helper functions
    
    private func getWrap(forArrangedSubview v: NSView) -> NoClipWrapper {
        
        if let wrapper = v.superview as? NoClipWrapper {
            return wrapper
        } else {
            fatalError()
        }
    }
    
    private func getFullHeight(_ v: NoClipWrapper, state: ArrangedSubViewState) -> Double {
        /// Make sure the relevant constraints that require the wrapped view to be the desired height are applied to the wrapped view before calling this.
        
        /// Declare result
        let result: Double
        
        /// Record og constraints
        let heightWasActive = state.wrapperHeightConstraint!.isActive
        let bottomWasActive = state.bottomConstraint!.isActive
        
        /// Configure constraints for height measurement
        if heightWasActive {
            state.wrapperHeightConstraint?.isActive = false
        }
        if !bottomWasActive {
            state.bottomConstraint?.isActive = true
        }
        
        /// Force layout
        v.needsLayout = true
        v.layoutSubtreeIfNeeded()
        
        /// Get result
        result = v.frame.height
        
        /// Restore constraints
        if !bottomWasActive {
            state.bottomConstraint?.isActive = false
        }
        if heightWasActive {
            state.wrapperHeightConstraint?.isActive = true
        }
        
        /// Restore layout
        if heightWasActive || !bottomWasActive {
            v.needsLayout = true
            v.layoutSubtreeIfNeeded()
        }
            
        /// Return
        return result
    }
    
    /// Prepare arranged subview for collapsing
    private func makeArrangedSubviewCollapsable(_ v: NSView) {
        
        /// Guard: already collapsable
        let state = arrangedSubViewState(forView: v)
        if state.isCollapsable { return }
        
        /// Get index of v
        let vIndex = arrangedSubviews.firstIndex(of: v)!
        
        /// Determine which spacing to remove
        
        let isLast = vIndex+1 == arrangedSubviews.count
        let isFirst = vIndex == 0
        
        var edgeToRemoveSpacingFrom: String = "none"
        if !isLast {
            edgeToRemoveSpacingFrom = "bottom"
        } else if !isFirst {
            edgeToRemoveSpacingFrom = "top"
        }
        
        /// Get amount of spacing to remove
        var spacingToRemove: Double
        if edgeToRemoveSpacingFrom == "bottom" {
            spacingToRemove = customSpacing(after: v)
        } else if edgeToRemoveSpacingFrom == "top" {
            let prevView = arrangedSubviews[safe: vIndex-1]!
            spacingToRemove = customSpacing(after: prevView)
        } else if edgeToRemoveSpacingFrom == "none" {
            spacingToRemove = 0.0
        } else {
            fatalError()
        }
        if spacingToRemove == NSStackView.useDefaultSpacing {
            spacingToRemove = spacing
        }
        
        /// Embed v in wrapperView
        ///     Could maybe simply use self.replaceSubview()
        
        removeArrangedSubview(v)
        let wrapper = NoClipWrapper()
        wrapper.addSubview(v)
        insertArrangedSubview(wrapper, at: vIndex)
        
        /// Request layer backing on wrapper to allow opacity animations
        wrapper.wantsLayer = true
        
        /// Add layoutConstraints onto wrapperView that add the spacing to remove
        
        var topSpacingToRemove = 0.0
        var bottomSpacingToRemove = 0.0
        if edgeToRemoveSpacingFrom == "top" {
            topSpacingToRemove = spacingToRemove
        } else if edgeToRemoveSpacingFrom == "bottom" {
            bottomSpacingToRemove = spacingToRemove
        }
        
        let leadingConst = v.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor)
        let trailingConst = v.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor)
        let topConst = v.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: topSpacingToRemove)
        let bottomConst = v.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -bottomSpacingToRemove)
        /// Create height constraint on wrapper which we'll later animate
        let collapseConstraint = wrapper.heightAnchor.constraint(equalToConstant: 0)
        
        /// Activate the constraints
        leadingConst.isActive = true
        trailingConst.isActive = true
        topConst.isActive = true
        bottomConst.isActive = true
        collapseConstraint.isActive = false
        
        /// Remove the spacing from the tableView
        if edgeToRemoveSpacingFrom == "bottom" {
            setCustomSpacing(0.0, after: wrapper)
        } else if edgeToRemoveSpacingFrom == "top" {
            let prevView = arrangedSubviews[safe: vIndex-1]!
            setCustomSpacing(0.0, after: prevView)
        }
        
        /// Save state
        
        state.bottomConstraint = bottomConst
        state.wrapperHeightConstraint = collapseConstraint
        
        state.isCollapsable = true
    }
    
    // MARK: - Definitions

    private func getAnimationDuration(animationDistance: Double) -> CFTimeInterval {
        
        /// This is unused now since we're using SpringAnimations
        
        /// Slow down large animations a little for consistent feel
        let baseDuration = 0.25
        let speed = 180 /// px per second. Duration can be based on this. For some reasons large animations were way too slow with this
        let proportionalDuration = abs(animationDistance) / Double(speed)
        let normalizationFactor = 0.9
        let duration = (1-normalizationFactor) * proportionalDuration + (normalizationFactor) * baseDuration
        
        return duration
    }

    /// Define collapse animation curves
    ///     This is unused now since we're using SpringAnimations
    
    private let collapseHeightCurve = CAMediaTimingFunction(name: .default)
    private let expandHeightCurve = CAMediaTimingFunction(name: .default)

    /// Define fade animation curves
    
    private let collapseAlphaCurve = CAMediaTimingFunction(controlPoints: 0, 1, 0.5, 1)
    private let expandAlphaCurve = CAMediaTimingFunction(controlPoints: 1, 0, 0.5, 1)
    /// ^ Use different animation curve than the height animation (below). The goal is to keep the opacity low for most of the animation to hide jankyness, while still maintaining a nice fresh "easeOut feel" to them

    /// Good curves
    ///     Curves for paralax animation with no scaling on screenshot
    ///         collapse    controlPoints: 0, 1, 0, 1,
    ///         expand      controlPoints: 1, 0, 0.5, 1
    ///     Curves for paralax animation with scaling on screenshot (more alpha)
    ///         collapse    controlPoints: 0, 0.8, 0, 1
    ///         expand      controlPoints: 1, 0, 0.5, 1
    ///     Curves for stationary fade animation
    ///         collapse    controlPoints: 0, 1, 0.5, 1
    ///         expand      controlPoints: 1, 0, 0.5, 1

}
