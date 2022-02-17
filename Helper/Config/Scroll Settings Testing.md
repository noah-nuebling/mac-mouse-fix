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
- > This is really good!! 30 and 0.8 are the exact parameters we use in GestureScrollSimulator to approximate the curve of Apples Trackpad driver. This feels great!! Since it's the same curve, we can even send these events as MomentumScroll events which will make the overscroll feels amazing! I'll almost certainly go with this for the Inertial scrolling.
