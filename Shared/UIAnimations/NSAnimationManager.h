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

#ifndef NSAnimationManager_h
#define NSAnimationManager_h

@class NSMutableArray;

@interface NSAnimationManager : NSObject {
    NSMutableArray* _pendingStartAnimations;
}

+ (NSAnimationManager *)currentAnimationManager;

+ (void)observeValueForKeyPath:(id)arg1 ofObject:(id)arg2 change:(id)arg3 context:(void*)arg4;
+ (void)performAnimations:(NSArray<CAAnimation *> *)animations; /// What is arg? ... not an animationManager instance. Probably CAAnimationsArray?

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
- (void)removeAllAnimationsForObject:(id)arg1;
- (void)removeAnimationsForObject:(id)arg1 keyPath:(id)arg2;
- (void)removeAnimationsForObject:(id)arg1 keyPath:(id)arg2 finished:(BOOL)arg3;

/// Dealloc
- (void)dealloc;

@end

#endif /* NSAnimationManager_h */
