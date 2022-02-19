#  Scroll Settings Testing

(Using BezierHybridCurve for everything)

__Normal settings__

We should base this off of the old MMF algorithm. -> Also use a BezierHybrid curve. No one has ever complained that the old algorithm is 'too inertial' or anything

__Inertial settings__

1. Inertial base 
- pxPerTickBase: 60
- pxPerTickEnd: 120
- BaseCurve: (0,0), (0,0), (1,1), (1,1) 
- msPerStep: 220
- dragCoefficient: 15
- dragExponent: 1.0
- stopSpeed: 20.0
- > This is nice. Swipes might take a little too long

1.2. Inertial fast stop
- pxPerTickBase: 60
- pxPerTickEnd: 120
- BaseCurve: (0,0), (0,0), (1,1), (1,1) 
- msPerStep: 220
- dragCoefficient: 15
- dragExponent: 1.0
- stopSpeed: 50.0
- > This stop speed is in line with MOS and prevents 'pixel creep'

1.3. Inertial Fast comedown
- pxPerTickBase: 60
- pxPerTickEnd: 120
- BaseCurve: (0,0), (0,0), (1,1), (1,1) 
- msPerStep: 220
- dragCoefficient: 6.5
- dragExponent: 1.2
- stopSpeed: 20.0
- > Similar to 1. but with higher exp to make it slow down from high speed faster. (And lower coefficient to balance it out). Feels weird for some reason.

2. Trackpad-style
- pxPerTickBase: 60
- pxPerTickEnd: 160
- BaseCurve: (0,0), (0,0), (1,1), (1,1) 
- msPerStep: 200
- dragCoefficient: 30
- dragExponent: 0.8
- stopSpeed: 50
    - This is really good!! 30 and 0.8 are the exact parameters we use in GestureScrollSimulator to approximate the curve of Apples Trackpad driver. This feels great!! Since it's the same curve, we can even send these events as MomentumScroll events which will make the overscroll feels amazing! I'll almost certainly go with this for the Inertial scrolling.

2.2 Actual trackpad-style (too floaty)
- pxPerTickBase: 60
- pxPerTickEnd: 160
- BaseCurve: (0,0), (0,0), (1,1), (1,1) 
- msPerStep: 200
- dragCoefficient: 30
- dragExponent: 0.7
- stopSpeed: 50
    - Edit: I just found the real GestureScrollSimulator values are 30 and 0.7 (not 0.8). That's a bummer because 0.7 is too floaty imo. 

2.2 Xcode momentum 1
- pxPerTickBase: 60
- pxPerTickEnd: 160
- BaseCurve: (0,0), (0,0), (1,1), (1,1) 
- msPerStep: 200
- dragCoefficient: 27
- dragExponent: 0.8
- stopSpeed: 50
    - Edit: We don't actually need to emulate the real trackpad output. Our momentumScroll phase just needs to not be noticably shorter than the Xcode generated momentum scroll. Because if it is, then the Xcode momentumScroll will get cut short (And many other apps have this problem, too). That's our only constraint I think. Since the Xcode momentum scroll is shorter and snappier than the real momentum scroll, we're in luck! We don't have to use the floaty 2.2 settings.
    -> These settings feel pretty similar to the Xcode momentum scroll to me. 
    -> We'll have to test these values once we have the Hybrid curve momentum scroll algorithm, to know if they work or if they cut short / differ too much from the the Xcode animation. 
    -> (Stop speed can differ from Xcode animation I think since there we want to cut the animation short.)
    -> Actually the time till it slows down at high speeds is much shorter than Xcode at 0.8... Might not work after all

2.2 Xcode momentum 2 (more accurate to Xcode)
- pxPerTickBase: 60
- pxPerTickEnd: 160
- BaseCurve: (0,0), (0,0), (1,1), (1,1) 
- msPerStep: 200
- dragCoefficient: 40
- dragExponent: 0.7
- stopSpeed: 50

2.3 Xcode momentum 3 (more snappy)
- pxPerTickBase: 60
- pxPerTickEnd: 160
- BaseCurve: (0,0), (0,0), (1,1), (1,1) 
- msPerStep: 220
- dragCoefficient: 40
- dragExponent: 0.7
- stopSpeed: 50
    -> Increasing the msPerStep actually makes the time taken for small flicks shorter
    
2.3 Xcode momentum 4 (ticks feel awesome)
- pxPerTickBase: 60
- pxPerTickEnd: 160
- BaseCurve: (0,0), (0,0), (1,1), (1,1) 
- msPerStep: 205
- dragCoefficient: 40
- dragExponent: 0.7
- stopSpeed: 50
    -> Might be placebo, but I think the 205 msPerStep makes single ticks feel nicer

3. Snappy
- pxPerTickBase: 60
- pxPerTickEnd: 160
- BaseCurve: (0,0), (0,0), (1,1), (1,1) 
- msPerStep: 180
- dragCoefficient: 10
- dragExponent: 1.1
- stopSpeed: 50
