#  Scroll Settings Testing

(Using BezierHybridCurve for everything)

__Final Settings__
(The settings which will appear in the app)

1. Low Inertia


2. Mid Inertia
→ Use "3.1 Snappy 2"

3. High Inertia
→ Use "2.3 Xcode Momentum 4"
→ If you simply switch on the "sendMomentumScrolls" setting in ScrollConfig.swift, then these settings will be automatically applied

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

3.1 Snappy 2
- pxPerTickBase: 40
- pxPerTickEnd: 110 
- BaseCurve: (0,0), (0,0), (1,1), (1,1) 
- msPerStep: 140
- dragCoefficient: 10
- dragExponent: 1.1
- stopSpeed: 50

4. MMF 1

---

__Acceleration Settings__

Low acceleration
- pxPerTickBase: 10 (Low), 30 (Mid), 60 (High)
- pxPerTickEnd: 80

Mid acceleration
- pxPerTickBase: 30
- pxPerTickEnd: 110

High acceleration
- pxPerTickBase: 60
- pxPerTickEnd: 160

Testing

Max good-feeling pxPerTickEnd

- Screensize: 2160, 2.3 Xcode Momentum 4 –– 180
- Screensize: 2160, 3.1 Snappy 2 –– 130
- Screensize: 1080, 2.3 Xcode Momentum 4 –– 160
- Screensize: 1080, 3.1 Snappy 2 –– 110

Min good-feeling pxPerTickEnd

- Screensize: 1080, 2.3 Xcode Momentum 4 –– 80

Idea for formula to calculate pxPerTickEnd: (based on the tests above)

```
pxPerTickEnd = pxPerTickEndBase * inertiaFactor + screenHeightSummant
where
    pxPerTickEndBase =
        160 if pxPerTickEndSemantic = "large"
        120 if pxPerTickEndSemantic = "medium"
        80 if pxPerTickEndSemantic = "small"
where
    inertiaFactor = 
        1 if inertia="2.3 Xcode Momentum 4"
        2/3 if inertia="3.1 Snappy 2"
where
    screenHeightSummant = 
        (screenHeightFactor-1)*20 if screenHeightFactor > 1
        ((1/screenHeightFactor)-1)*-20 if screenHeightFactor < 1
            where screenHeightFactor = actualScreenHeight / 1080
```
→ Not sure if the screenHeightSummant makes sense. It's just constructed so that a screenHeightFactor of 2 creates a screenHeightSummant of 20px. 

Testing the formula: (pxPerTickEnd values based on the formula)

- Screensize 2160, "3.1 Snappy 2", "small" –– 80*(2/3) + 20 = 73 –– Feels good
- Screensize 1080, "3.1 Snappy 2", "small" –– 80*(2/3) = 53 –– Feels good
- Screensize 2160, "3.1 Snappy 2", "large" –– 160*(2/3) + 20 = 126 –– Feels good
- Screensize 2160, "3.1 Snappy 2", "large" –– 160*(2/3) + 20 = 126 –– Feels good
- Screensize 846, "3.1 Snappy 2", "large" –– 160*(2/3) - 5 = 102 –– Feels good
- Screensize 846, "3.1 Snappy 2", "large" –– 80*(2/3) - 5 = 48 –– Feels good

---

__Notes__

- Should msPerStep change as the user adjusts pxPerTick? - No I don't think so. It feels good with a constant msPerStep.
- Should the pxPerTick options change as the user chooses different inertial feels? - Yes. The more inertia, the more do larger pxPerTick (or at least pxPerTickEnd) make sense. 
- Should the pxPerTick options change when there is more screen real estate? - Maybe? It does feel more appropriate to use large pxPerTick (or at least pxPerTickEnd) with more screenSpace
