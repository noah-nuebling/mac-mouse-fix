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
    private var current: U { base.value(forKeyPath: self.keyPath) as! U }
    
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
            let animation = animation1!.copy() as! CABasicAnimation
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
//            animation.perform(.init("setDiscretizesTime:"), with: ObjCBool(true))
            
            /// Pass animation to animationManager
            if let animationManager = NSAnimationManager.current() {
                animationManager.setTargetValue(newValue, for: base, keyPath: keyPath, animation: animation)
            } else { /// Fallback
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
    
    /// Get subobjects
    public subscript<S>(dynamicMember keyPath: String) -> ReactiveAnimatorPropertyProxy<U, S> {
        let selfObject = base.value(forKeyPath: self.keyPath) as! U
        return ReactiveAnimatorPropertyProxy<U, S>(base: selfObject, keyPath: keyPath, type: type)
    }

}
