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
@import QuartzCore.CAAnimation;

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

/// Animation prototype resolution
///     - Necessary under macOS 15 Sequoia
///     - Backported this from the feature-strings-catalog branch into the master branch. See the feature-strings-catalog branch for more info. (last updated: 16.09.2024)
- (CAAnimation *)animationForObject:(id)object key:(NSString *)keyPath targetValue:(id)targetValue API_AVAILABLE(macos(15.0));

@end

#endif /* NSAnimationManager_h */
