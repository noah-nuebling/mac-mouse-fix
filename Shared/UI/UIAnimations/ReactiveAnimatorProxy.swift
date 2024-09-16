//
//  NSTextFieldExtension.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 25.07.21.
//

/// Makes it possible to bind values to an NSTextField via ReactiveSwift and have the value changes animate

import Foundation
import AppKit
import ReactiveSwift
import ReactiveCocoa

fileprivate enum AnimationType {
    case normal
    case fade
}

extension NSAnimatablePropertyContainer where Self: NSObject {

    public func reactiveAnimator() -> ReactiveAnimator<Self> {
        return ReactiveAnimator(base: self, type: .normal)
    }
    public func reactiveFadeAnimator() -> ReactiveAnimator<Self> {
        return ReactiveAnimator(base: self, type: .fade)
    }
}

@dynamicMemberLookup public struct ReactiveAnimator<Base> where Base: NSObject, Base: NSAnimatablePropertyContainer {
    
    fileprivate let base: Base
    fileprivate let type: AnimationType
    
    fileprivate var baseAsView: NSView? {
        if let baseAsView = self.base as? NSView {
            return baseAsView
        } else {
            return nil
        }
    }
    
    public subscript<U>(dynamicMember keyPath: String) -> ReactiveAnimatorPropertyProxy<Base, U> {
        return ReactiveAnimatorPropertyProxy(base: base, keyPath: keyPath, type: type)
    }
}

@dynamicMemberLookup public struct ReactiveAnimatorPropertyProxy<Base: NSObject, U>: BindingTargetProvider {
    
    /// Storage
    private let base: Base
    private let keyPath: String
    private let type: AnimationType
    
    /// Convenience
    private var current: U? { base.value(forKeyPath: self.keyPath) as! U? }
    
    /// Init
    fileprivate init(base: Base, keyPath: String, type: AnimationType) {
        self.base = base
        self.keyPath = keyPath
        self.type = type
    }
    
    /// BindingTargetProvider protocol implementations
    public var bindingTarget: BindingTarget<U> {
        return BindingTarget(on: UIScheduler(), lifetime: Lifetime.of(self.base)) { (newValue) -> Void in
            self.set(newValue)
        }
    }
    
    /// Main function
    func set(_ newValue: U) {
        switch type {
        case .normal:
            
            /// Note: Use setAnchorPoint before doing transforms
            
            /// Get animation from context
            var animation1 = CATransaction.value(forKey: "reactiveAnimatorPayload") as? CABasicAnimation /// Get animation from context (set in `Animate.with()`)
            if animation1 == nil { /// Fallback
                animation1 = CABasicAnimation(name: .default, duration: 0.25)
            }
            
            /// Guard 0 duration
            if animation1!.duration == 0 {
                base.setValue(newValue, forKeyPath: keyPath)
                return
            }
            
            /// Make copy so we don't change the animation outside this scope
            var animation = animation1!.copy() as! CABasicAnimation

            /// Make animations round to integer to avoid jitter. This is useful for resize animations. But this breaks opacity animations.
            var doRoundToInt = false
            if (newValue as? NSRect) != nil { doRoundToInt = true }
            if let current = current as? Double, let newValue = newValue as? Double {
                let difference = abs(current - newValue)
                if difference > 5 {
                    doRoundToInt = true
                }
            }
            if doRoundToInt {
                animation.perform(.init(Selector(("setRoundsToInteger:"))), with: ObjCBool(true))
            }
            
            /// Do other stuff to avoid jitter (nothing works)
//            animation.isAdditive = true
            
            /// Do the animation
            
            if let newValue = newValue as? NSShadow, let base = base as? NSView {
                    
                ///
                /// Special case: shadows
                ///
                
                /// Seems like you need to set a shadow before you play this animation for the first time, or it looks weird. Where 'before' means way before. Not during the same (runLoop cycle?) (rendering cycle?) that you call this the first time.
                
                if base.shadow == nil {
//                    base.wantsLayer = true
                    base.shadow = .clearShadow
//                    base.updateLayer()
//                    base.layer.shadow
                    
                }
//                if base.shadow == .clearShadow {
//                    base.layer.preset
//                }
                
                /// Prevent animation from resetting after completion (not necessary for animationManager I think)
                animation.fillMode = .forwards
                animation.isRemovedOnCompletion = false
                
                /// Try to get the layerPresentation to sync up with the the frst time this animation plays. doesn't work
                base.needsDisplay = true
                base.displayIfNeeded()
                base.layer?.setNeedsDisplay()
                base.layer?.displayIfNeeded()
                
                let c = animation.copy() as! CABasicAnimation //newValue.shadowColor
                let r = animation.copy() as! CABasicAnimation //newValue.shadowBlurRadius
                let o = animation.copy() as! CABasicAnimation //newValue.shadowOffset
                
                c.fromValue = base.shadow?.shadowColor
                c.toValue = newValue.shadowColor
                
                r.fromValue = base.shadow?.shadowBlurRadius
                r.toValue = newValue.shadowBlurRadius
                
                o.fromValue = base.shadow?.shadowOffset
                o.toValue = newValue.shadowOffset
                
                base.layer?.add(c, forKey: "shadowColor")
                base.layer?.add(r, forKey: "shadowRadius")
                base.layer?.add(o, forKey: "shadowOffset")

                CATransaction.setCompletionBlock {
                    base.shadow = newValue
                    CATransaction.completionBlock()?()
                }
                
            } else if let newValue = newValue as? CATransform3D, let base = base as? CALayer {
                
                /// Special case: transforms
                ///     This makes the `scale()` NSView extension obsolete
                
                animation.fromValue = base.presentation()?.value(forKeyPath: "transform")
                animation.toValue = newValue
                
                /// Prevent animation from resetting after completion (not necessary for animationManager I think)
                animation.fillMode = .forwards
                animation.isRemovedOnCompletion = false
                
                base.add(animation, forKey: "transform")
                
            } else if let animationManager = NSAnimationManager.current() {
                
                /// Default: Use animationManager
                
                /// macOS 15 Sequoia Fix
                ///     - This turns the 'animationPrototype' into a real animation afaik. See declaration for more info.
                ///     - Only do this on animations that will be performed by the animation manager! Doing this on shadow animations (which aren't performed by the manager) breaks the animations. (as of 16.09.2024)
                if #available(macOS 15.0, *) {
                    animation = animation.forObject(base, key: keyPath, targetValue: newValue) as! CABasicAnimation
                }
                
                /// Call animationManager
                animationManager.setTargetValue(newValue, for: base, keyPath: keyPath, animation: animation)
                
            } else { /// Fallback
                
                /// Fallback: Don't animate
                
                assert(false)
                base.setValue(newValue, forKeyPath: keyPath) /// Fallback
            }
        case .fade:
            do {
                guard let base = self.base as? NSView else {
                    throw NSException(name: .invalidArgumentException, reason: "Base is not a view", userInfo: nil) as! Error
                }
                try fade(on: base, property: keyPath, newValue: newValue)

            } catch {
                print("Fade animation failed: \(error)")
            }
        }
    }
    
    public subscript<S>(dynamicMember keyPath: String) -> ReactiveAnimatorPropertyProxy<U, S> {
        
        /// Get animators for properties of `base`
        let selfObject = base.value(forKeyPath: self.keyPath) as! U
        return ReactiveAnimatorPropertyProxy<U, S>(base: selfObject, keyPath: keyPath, type: type)
    }

}
