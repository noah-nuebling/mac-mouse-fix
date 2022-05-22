#  ScrollConfigTesting

(Using BezierHybridCurve for everything)

__Final Settings__
(The settings which will appear in the app)

1. Low Inertia
-> Use "4.2 MMF 3"

2. Mid Inertia
→ Use "3. Snappy"

3. High Inertia
→ Use "2.3 Xcode Momentum 4"
→ If you simply switch on the "sendMomentumScrolls" setting in ScrollConfig.swift, then the "2.3 Xcode Momentum 4" settings will be automatically applied

__Inertial settings__

1. __Inertial base__ 
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
- stopSpeed: 50.0 <- This changed
- > This stop speed is in line with MOS and prevents 'pixel creep'

1.3. Inertial Fast comedown
- pxPerTickBase: 60
- pxPerTickEnd: 120
- BaseCurve: (0,0), (0,0), (1,1), (1,1) 
- msPerStep: 220
- dragCoefficient: 6.5 <- These 
- dragExponent: 1.2 <-      changed
- stopSpeed: 20.0
- > Similar to 1. but with higher exp to make it slow down from high speed faster. (And lower coefficient to balance it out). Feels weird for some reason.

2. __Trackpad-style__
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
- dragExponent: 0.7 <- This changed
- stopSpeed: 50
    - Edit: I just found the real GestureScrollSimulator values are 30 and 0.7 (not 0.8). That's a bummer because 0.7 is too floaty imo. 

2.2 Xcode momentum 1
- pxPerTickBase: 60
- pxPerTickEnd: 160
- BaseCurve: (0,0), (0,0), (1,1), (1,1) 
- msPerStep: 200
- dragCoefficient: 27 <- These changed
- dragExponent: 0.8 <- 
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
- dragCoefficient: 40 <- 
- dragExponent: 0.7 <- These changed
- stopSpeed: 50

2.3 Xcode momentum 3 (more snappy)
- pxPerTickBase: 60
- pxPerTickEnd: 160
- BaseCurve: (0,0), (0,0), (1,1), (1,1) 
- msPerStep: 220 <- This changed
- dragCoefficient: 40
- dragExponent: 0.7
- stopSpeed: 50
    -> Increasing the msPerStep actually makes the time taken for small flicks shorter
    
2.3 Xcode momentum 4 (ticks feel awesome)
- pxPerTickBase: 60
- pxPerTickEnd: 160
- BaseCurve: (0,0), (0,0), (1,1), (1,1) 
- msPerStep: 205 <- This changed
- dragCoefficient: 40
- dragExponent: 0.7
- stopSpeed: 50
    -> Might be placebo, but I think the 205 msPerStep makes single ticks feel nicer
    -> Smaller msPerStep make single ticks feel even less stiff, but that makes time taken for small flicks longer. Might need more testing. Edit: 180 still feels nice, probably don't wanna go lower. As high as 280 still feels decent, but it makes the single ticks very stiff

3. __Snappy__
- pxPerTickBase: 60
- pxPerTickEnd: 160
- BaseCurve: (0,0), (0,0), (1,1), (1,1) 
- msPerStep: 180
- dragCoefficient: 10
- dragExponent: 1.1
- stopSpeed: 50

3.1 Snappy 2
- pxPerTickBase: 40 <- These changed
- pxPerTickEnd: 110 <-
- BaseCurve: (0,0), (0,0), (1,1), (1,1) 
- msPerStep: 140 <-
- dragCoefficient: 10
- dragExponent: 1.1
- stopSpeed: 50
    -> This is very snappy but still sort of floaty. I like "3. Snappy" and "4.2 MMF 3" better

4. __MMF__
- pxPerTickBase: 60
- pxPerTickEnd: 90
- BaseCurve: (0,0), (0,0), (1,1), (1,1) 
- msPerStep: 110
- dragCoefficient: 20
- dragExponent: 1.0
- stopSpeed: 50 
    -> This emulates the feel of the old MMF scrolling algorithm very closely
    
4.1 MMF 2
- pxPerTickBase: 60
- pxPerTickEnd: 90
- BaseCurve: (0,0), (0,0), (1,1), (1,1) 
- msPerStep: 140 <- These changed
- dragCoefficient: 25 <-
- dragExponent: 1.0
- stopSpeed: 50 
    -> This is very stiff, but medium speed scrolls are smoother
    
4.2 MMF 3
- pxPerTickBase: 60
- pxPerTickEnd: 90
- BaseCurve: (0,0), (0,0), (1,1), (1,1) 
- msPerStep: 140
- dragCoefficient: 23 <- This changed
- dragExponent: 1.0
- stopSpeed: 50 
    -> Little bit less stiff 

---

__Acceleration Settings__

pxPerTickBase: 
    10 (Low), 40 (Mid), 60 (High)

pxPerTickEnd:

Max good-feeling pxPerTickEnd

- Screensize: 2160, 2.3 Xcode Momentum 4 –– 180
- Screensize: 2160, 3.1 Snappy 2 –– 130
- Screensize: 1080, 2.3 Xcode Momentum 4 –– 160
- Screensize: 1080, 3.1 Snappy 2 –– 110

Min good-feeling pxPerTickEnd

- Screensize: 1080, 2.3 Xcode Momentum 4 –– 80

MMF1-feeling pxPerTickEnd

- Screensize: 846, "4. MMF" –– 80


Formula to calculate pxPerTickEnd: (based on the tests above)

```
pxPerTickEnd = pxPerTickEndBase * inertiaFactor + screenHeightSummant
where
    pxPerTickEndBase =
        160 if pxPerTickEndSemantic = "large"   (180 is good after making acceleration curve linear)
        120 if pxPerTickEndSemantic = "medium"  (130 or 140 might be better after making acceleration curve linear)
        80 if pxPerTickEndSemantic = "small"    (90 might be better after making acceleration curve linear)
where
    inertiaFactor = 
        1 if inertia="2.3 Xcode Momentum 4"
        3/4 if inertia="3 Snappy"
        2/3 if inertia="4. MMF"
where
    screenHeightSummant = 
        (screenHeightFactor-1)*20 if screenHeightFactor > 1
        ((1/screenHeightFactor)-1)*-20 if screenHeightFactor < 1
            where screenHeightFactor = actualScreenHeight / 1080
```
→ Not sure if the screenHeightSummant makes sense. It's just constructed so that 
    ```
    screenHeightSummant(screenHeightFactor = 1) = 0
    screenHeightSummant(screenHeightFactor = 2) = 20
    screenHeightSummant(screenHeightFactor = 1/x) = - screenHeightSummant(screenHeightFactor = x) –– (where x < 1)
    ``` 

Testing the formula: (calculating pxPerTickEnd values based on the formula)

- Screensize 2160, "3.1 Snappy 2", "small" –– 80*(2/3) + 20 = 73 –– Feels good
- Screensize 1080, "3.1 Snappy 2", "small" –– 80*(2/3) = 53 –– Feels good
- Screensize 2160, "3.1 Snappy 2", "large" –– 160*(2/3) + 20 = 126 –– Feels good
- Screensize 846, "3.1 Snappy 2", "large" –– 160*(2/3) - 5 = 102 –– Feels good
- Screensize 846, "3.1 Snappy 2", "small" –– 80*(2/3) - 5 = 48 –– Feels good
- Screensize 846, "4. MMF", "medium" –– 120*(2/3) - 5 = 75 –– Feels good
- Screensize 1080, "3. Snappy", "large" –– 160*(3/4) = 120 –– Feels good

-> Formula seems to work well enough

---

__Notes__

- Should msPerStep change as the user adjusts pxPerTick? - No I don't think so. It feels good with a constant msPerStep.
- Should the pxPerTick options change as the user chooses different inertial feels? - Yes. The more inertia, the more do larger pxPerTick (or at least pxPerTickEnd) make sense. 
- Should the pxPerTick options change when there is more screen real estate? - Maybe? It does feel more appropriate to use large pxPerTick (or at least pxPerTickEnd) with more screenSpace
