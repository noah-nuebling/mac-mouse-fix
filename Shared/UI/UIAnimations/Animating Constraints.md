#  Animating Constraints

We're trying to find a way to animate NSLayoutConstraints with custom CAAnimations. Specifically spring animations.

You can animate constraints using the animator proxy (`constraint.animator()`), but that doesn't allow you to fully customize the animation. You can only customize it using NSAnimationContext which only allows for Bezier-Curve-Based animations, not spring animations.

However, I read somewhere that the animator proxy is just a wrapper around CAAnimation. So it `should` be possible to animate constraints using custom CAAnimations as well. But I can't figure out a way.

Ideas:
- Subclass CAConstraintLayoutManager
    - You would think that NSLayoutConstraint is a wrapper for CAConstraint like NSAnimationContext is said to be a wrapper for CAAnimation. But this doesn't seem to be the case. The CAConstraint system seems to be incompatible with NSLayout. Also I tried subclassing CAConstraintLayoutManager, and assigning that to the animating layers but it didn't do anything.
- Step through assembly of proxy animator
    - This worked! See NSAnimationManager.h

