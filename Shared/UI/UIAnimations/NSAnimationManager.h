//
//  NSAnimationManager.h
//  tabTestStoryboards
//
//  Created by Noah Nübling on 03.08.22.
//
/// This is called when using animation proxy on NSLayoutConstraint.
/// -> Might allow us to customize the animation used to animate layoutConstraints.
///
/// Specifially I saw the following functions being called stepping through disassembly:
///     - First `currentAnimationManager` is called to get a a class instance (IIRC)
///     - Then, `setTargetValue:forObject:keyPath:animation:` is called which seems to be a wrapper for `setTargetValue:forObject:keyPath:animation:options:`
/// Then I found this header  on github:
///     https://github.com/cmsj/ApplePrivateHeaders/blob/7d0c0200eeb7c3e326fafd4bbd7b6786f8000730/macOS/11.3/System/Library/Frameworks/AppKit.framework/Versions/C/AppKit/NSAnimationManager.h
/// Then I sorted the methods, and filled out some of the argument types and names as it made sense.
///
/// -> It works!!

#import <AppKit/AppKit.h>
#import <QuartzCore/CAAnimation.h>

#ifndef NSAnimationManager_h
#define NSAnimationManager_h

@class NSMutableArray;

@interface NSAnimationManager : NSObject {
    NSMutableArray* _pendingStartAnimations;
}

+ (NSAnimationManager *)currentAnimationManager;

+ (void)observeValueForKeyPath:(id)arg1 ofObject:(id)arg2 change:(id)arg3 context:(void*)arg4;
+ (void)performAnimations:(NSArray<CAAnimation *> *)animations;

/// Start animation
- (void)setTargetValue:(id)targetValue forObject:(id)object keyPath:(NSString *)keyPath animation:(CAAnimation *)animation;
- (void)setTargetValue:(id)targetValue forObject:(id)object keyPath:(NSString *)keyPath animation:(CAAnimation *)animation options:(long long)options;

/// Query
- (id)targetValueForObject:(id)arg1 keyPath:(id)arg2;
- (id)animationForObject:(id)arg1 keyPath:(id)arg2;
- (BOOL)hasAnimationForObject:(id)arg1 keyPath:(id)arg2;

/// Interrupt
- (void)interruptAnimationsForObject:(id)arg1 keyPath:(id)arg2;

/// Remove
- (void)removeAllAnimationsForObject:(id)object;
- (void)removeAnimationsForObject:(id)object keyPath:(NSString *)keyPath;
- (void)removeAnimationsForObject:(id)object keyPath:(id)keyPath finished:(BOOL)finished;

/// Dealloc
- (void)dealloc;

@end

@interface CAAnimation (MF_NSPrototypeAnimation)

/// Animation prototype stuff
/// Explanation:
///     Under macOS 15.0 Beta, collapsable-stackView- and fade-animations broke.
///     To fix it we had to call `animation = [animation animationForObject:key:targetValue:]`
///     before passing an animation to the animationManager inside ReactiveAnimatorProxy.swift.
/// Notes:
///     We're marking API with `API_AVAILABLE(macos(15.0)` since we only tested it on macOS 15.0. But it might be available before macOS 15.0.
///
///     Tips in case this breaks again:
///          I found this by stepping through the assembly for `view.animator().alphaValue = <something>`, and seeing how the
///          native animatorProxy implementation differed from our ReactiveAnimatorProxy.swift implementation. (Use `breakpoint set -n <methodSelector>` to skip objc `message_send` when assembly-stepping)
///
///     Discussion on current system:
///         I feel a bit bad about ReactiveAnimatorProxy.swift. It's quite messy and seems prone to breaking as it did here.
///         From my current understanding, the reason we introduced the ReactiveAnimatorProxy.swift in the first place was so that:
///             1. So that we can assign values using ReactiveSwift and have those value assignments be animated (we do this by making our animatorProxy a ReactiveSwift BindingTargetProvider)
///             2. So we can use custom CAAnimations with an animator proxy, which we couldn't figure out a way to do otherwise
///                 (NSAnimationContext only lets you specify one of 4 or 5 `timingFunctions` iirc, CALayer has methods for animating with a specific animation, but that is very cumbersome and might not apply in all places where we use animator proxies. E.g. when animating a layoutConstraint, then no CALayers are directly involved afaiu. NSAnimatablePropertyContainer lets you specify an animation by replacing the `animations` dict, this could actually be a viable solution, but not sure.)
///
///     Possible improvement to the current system:
///         We should be able to add the reactive stuff in an `_NSObjectAnimator` extension, (or we can just do without reactive stuff or see if Apples Combine has more native integration).
///         For customizing animations, we should be able to either replace the animation that NSAnimationContext stores on the thread dictionary (I think it does that?) or we could perhaps  override the NSAnimatablePropertyContainer.animations dict.
///         The custom code inside ReactiveAnimatorProxy.swift for handling shadows and stuff is I think just a reimplementation of the logic inside the system's animator proxies (Which I think are `_NSViewAnimator` and other `_NSObjectAnimator` subclasses.)
///         -> Conclusion: By extending `_NSObjectAnimator` to add ReactiveSwift integration and writing a simple NSAnimationContext replacement, we might be able to fullly replace the functionality of ReactiveAnimatorProxy.swift in a simpler way. However, having a completely custom animatorProxy does give us more control, even though it's more prone to breaking due to relying on private methods and re-implementation of some native functionality.

- (CAAnimation *)animationForObject:(id)object key:(NSString *)keyPath targetValue:(id)targetValue API_AVAILABLE(macos(15.0));

@end

#endif /* NSAnimationManager_h */
