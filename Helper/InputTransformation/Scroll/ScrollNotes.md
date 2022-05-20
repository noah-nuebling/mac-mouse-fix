#  ScrollNotes

- It might've made things easier if we implemented __Monotone Cubic Interpolation__ (https://en.wikipedia.org/wiki/Monotone_cubic_interpolation)
    - This might have been better suited (than the Bezier and Drag Curves we ended up using) to define the acceleration and animation curves that we use for scrolling
    - IIRC in the registry explorer you can also see curve definitions for mouse acceleration and trackpad animation curves in Apple's own drivers. IIRC these curves are given as many control points -> They seem to be using interpolation. So we could maybe datamine and use the Apple curves if we had an interpolator class. This would've been useful to emulate the momentum scrolling curve. But now it's too late and it works fine the way we've built it.
    
