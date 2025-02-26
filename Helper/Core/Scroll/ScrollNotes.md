# ScrollNotes

## Monotone Cubic Interpolation
- It might've made things easier if we implemented __Monotone Cubic Interpolation__ (https://en.wikipedia.org/wiki/Monotone_cubic_interpolation)
    - This might have been better suited (than the Bezier and Drag Curves we ended up using) to define the acceleration and animation curves that we use for scrolling
    - IIRC in the registry explorer you can also see curve definitions for mouse acceleration and trackpad animation curves in Apple's own drivers. IIRC these curves are given as many control points -> They seem to be using interpolation. So we could maybe datamine and use the Apple curves if we had an interpolator class. This would've been useful to emulate the momentum scrolling curve. But now it's too late and it works fine the way we've built it.
    
## Scrolling Jank 
    (that I'm aware of as of [Feb 2025]) 

- iOS & iPad apps:
    When running iPad apps from the App Store on the Mac, the 'opposite-tick' feature doesn't work sometimes.
- Universal Control & iPhone Mirroring:
    I forgot what's wrong but I got quite a few issue reports.
- Launchpad:
    When using "Click and Scroll" to open launchpad and then reversing scroll-direction mid animation, it immediately goes to the desktop. Possibly related to the 'opposite-tick' feature.
- Safari:
    When zoom in Safari and reversing scroll direction mid animation, it janks out more than a Trackpad would. Possibly related to the 'opposite-tick' feature. 

Sidenote: What is the 'opposite-tick' feature?
    -> It's when you move the scroll wheel one tick in the opposite direction to stop scrolling. We introduced that in [3.0.2](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2).
