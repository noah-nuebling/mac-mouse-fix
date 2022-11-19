//
//  Animation.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 03.08.22.
//

/// Class for convenience methods for animating views
/// Use reactiveAnimator inside the closure to use the animation that this sets

/// \Issue:
///     Since moving over to the new animations using Animate + reactiveAnimator + NSAnimationManager + CASpringAnimation for everything, all the animations have this pixeljitter to them. Not sure why. Probably either CASpringAnimation or NSAnimationManager. Before we were using NSAnimationContext for most things and NSWindow.setFrame() for windowAnimation. That didn't have the jitter.
///     Last commit with old anmations: 9a6a1dca092234a75a23e4dd11d77b81eda43114
///     Edit: Fixed this mostly by setting `roundsToInteger` on the animation in ReactiveAnimatorProxy, but it's still slightly more jittery than before.
///
/// Edit: A lot of the work we did is a little unnecessary since you can simply use a custom animation `caAnimation` to animate anything including layoutConstraints without using the private NSAnimationManager API like this:
///     ```
///     var animationMap = animatablePropertyContainer.animations
///     animationMap["propertyToAnimate"] = caAnimation
///     animatablePropertyContainer.animations = animationMap
///     animatablePropertyContainer.animator().propertyToAnimate = targetValue
///     ```


import Foundation
import QuartzCore

@objc class Animate: NSObject {
    
    @objc static func with(_ animation: CAAnimation, changes: () -> (), onComplete: (() -> ())? = nil) {
        /// Configure animation
        
        /// This is unnecessary
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        
        /// Guard animationDuration == 0.0
        

        

        /// Lock
        /// Locking seems to sometimes create a deadlock with the addField hoveranimation where one thread is waiting for something on the "NSCGSTransactionAfter" queue and the other is on the mainQueue waiting for CA::Transaction::commit().
        /// I'll just disable locking now and hope for the best. Not sure what it does anyways.
        
//        CATransaction.lock()
        
        /// Do changes
        CATransaction.begin()
        if animation.duration != 0 {
            CATransaction.setCompletionBlock(onComplete) /// Need to set this before making changes to work
        }
        CATransaction.setValue(animation, forKey: "reactiveAnimatorPayload")
        changes()
        CATransaction.setValue(nil, forKey: "reactiveAnimatorPayload")
        if animation.duration == 0 {
            onComplete?() /// Do onComplete synchronously if no animation
        }
        CATransaction.commit()
        
        /// Unlock
//        CATransaction.unlock()
    }
}
