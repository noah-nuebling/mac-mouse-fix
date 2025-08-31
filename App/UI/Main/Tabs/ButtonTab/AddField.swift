//
// --------------------------------------------------------------------------
// AddField.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//


/// Old notes from `updateColors()`
///     (That function has now been deleted [Aug 2025])
///     This explain the history of how we used to handle colors and how we arrived at the current approach (Using an `NSVisualEffectView`) [Aug 2025]
///     Old Notes:
///         Explanation / why this is complicated [Aug 2025]
///         We want the AddField to simply look like a NSPrimaryBox with a '+' in the middle.
///         And that's exactly what the AddField was in MMF 2
///         However, in MMF 3, we wanted to a an effect where the AddField raises slightly when you hover over it. The 'raise' effect applies a shadow to the AddField.
///         Problem:
///             NSPrimaryBox is transparent, so when you apply a shadow to make it look raised up, it just looks blurry!
///         Solution ideas:
///         - Apply non-transparent custom colors
///             -> but those don't support wallpaper tinting, which ends up looking broken.
///         - Override draw()
///             - Old comment said it breaks desktop tinting even if we just call super.draw() [Aug 2025]
///         - Choose specific *system* NSColors for which NSBox *does* enable wallpaper tinting:
///             -> The solution we shipped for MMF 3
///                 – This made the code a bit more complicated and less maintainable since we have to draw an NSCustomBox which emulates an NSPrimaryBox. We also didn't manage to perfectly emulate the look, since only 4 NSColors were available (See below)
///         - Try to render a custom NSShadow to a bitmap and then draw that
///             -> Too complicated (See 35742760e0bb0c126e16183f11f65532953822cb)
///         - Set .windowBackgroundColor to the NSBox's CAlayer
///             -> This allows you to use NSPrimaryBox instead of NSCustomBox, which simplifies things.
///             -> Almost works but also doesn't support wallpaper tinting.
///         - Try to find some private API that gives you the 'wallpaperTintColor' and then mix that in with your NSColors
///             -> I don't think this exists. Evidence:
///                 - When you set one of the special system colors that enable wallpaper tinting to NSBox, the NSBox will actually secretly insert an *NSVisualEffectView* as its subview. Also, other views than NSBox don't support wallpaper tinting at all. So it seems wallpaper tinting always requires an NSVisualEffectView and cannot be done at the NSColor level (Which would be much simpler and more flexible, and which the NSColor docs kinda made me think)
///                     Also see: Disassembly of `[_NSBoxMaterialCapableCustomView _updateSubviews]` on macOS Tahoe Beta 8
///                 - This kind of makes sense from a security perspective. If apps could directly access the colors of the windows behind them, then they could possibly reconstruct a sharp image of the background-windows via "multi-frame super-resolution" techniques. I assume that, instead, the `NSVisualEffectBlendingModeBehindWindow` happens in that background process that does the CALayer rendering or whatever. [Aug 2025]
///         - Take a screenshot of a tinted view and then sample the color to get the 'wallpaperTintColor' to mix with your NSColors.
///             -> This could work – IIRC, we're already taking such screnshots for the ResizingTabWindow transitions ... but that's using the deprecated CGWindowListCreateImage() API.
///         - Put our own NSVisualEffectView behind / inside the NSBox
///             -> Since this is what NSBox does natively (See above), it may be the most robust approach.
///             -> This way we could simply keep using NSPrimaryBox, to get the desired styling with little effort
///             -> Changed to this approach after MMF 3.0.7
///
///         Also see:
///             - This old, reverted commit from 2022 35742760e0bb0c126e16183f11f65532953822cb
///                 - Here, we tried to render the NSShadow to a bitmap (See above)
///                 - We also found 4 NSColors for which NSBox enables wallpaper tinting: .controlBackgroundColor, .textBackgroundColor, .underPageBackgroundColor, .windowBackgroundColor
///                     (found them by searching for 'background', maybe there are more)
///             - The commit before we removed all the old comments in `updateColors()`, and wrote one, comprehensive comment up top [Aug 2025] e7fc400a0ac84baba4b9ad2548f3cdecf906272c
///             - The solidColor methods from NSColor+Additions.m – Older comments said we tried those here but they didn't work
///             - `[NSAppearance performAsCurrentDrawingAppearance:]` -> This lets you correctly 'flatten' an NSColor to a CGColor or RGB while respecting darkmode/lightmode
///                 - See: https://stackoverflow.com/a/79490975/10601702
///                 - Didn't end up using this (Can't support desktop tinting – need `NSVisualEffectView` for that I think.
///
///         Sidenotes:
///             - We could simplify some of the `updateColors()` code using `+[NSColor colorWithName:dynamicProvider:]` instead of listening to darkmode changes directly. However, that had a bug that broke desktop tinting on earlier Tahoe Betas until we filed FB18739714 with Apple. (Thanks to that Apple Engineer!) (I assume it was also broken on Sequoia, but I didn't test.)
///                 - Also see:  [Jun 2025]  `mfl_dynamiccolor()` wrapper around  `+[NSColor colorWithName:dynamicProvider:]` which we wrote in the `swiftui-test-tahoe-beta` project.

import Cocoa
import CocoaLumberjackSwift

@objc class AddField: NSBox {

    /// Storage
    
    @IBOutlet var plusIconView: NSImageView!
    func plusIconViewBaseColor() -> NSColor { return NSColor.systemGray }
    
    var appearanceObservation: NSKeyValueObservation? = nil
    
    func coolInit() {
        
        /// Layer
        self.wantsLayer = true /// [Aug 2025] Not sure if necessary
        
        /// Override plusIcon on older macOS
        /// Explanation: We bundle an svg fallback for the SFSymbol that is used by default, but the resolution is wayy to low it's rendered too large. Maybe there's a more elegant solution but this should work.
        /// Notes:
        /// - Actually maybe we should just use NSAddTemplate in the first place even on newer macOS?
        /// - I think this makes it unnecessary that we bundle the svg fallback for the 'add' SFSymbol
        
        if #available(macOS 11.0, *) { }
        else                         { plusIconView.image = NSImage(named: NSImage.addTemplateName) }
        
        /// Set plusIcon color
        if #available(macOS 10.14, *) { plusIconView.contentTintColor = plusIconViewBaseColor() }
        
        /// Use standard box
        self.boxType = .primary
                
        /// Fix hover animations
        ///     Need to set some shadow before (and not directly, synchronously before) the hover animation first plays. No idea why this works
        self.shadow = .clearShadow
        plusIconView.shadow = .clearShadow
        
    }
    
    override func layout() {
            
        super.layout()
        
        /// Insert a NSVisualEffectView into the box
        ///     - We have to insert the `NSVisualEffectView` after `super.layout()` because the view that draws the NSBox's appearance is inserted in `[NSBox layout]` as the lowest subview, and we need to insert our `NSVisualEffectView` *below  that*.
        ///         - Observed this on macOS Tahoe Beta 8 – seems to work on older macOS versions, too.
        ///         - Trivia: On Tahoe and Sequoia, when using NSPrimaryBox, this drawing-view seems to be a straight up SwiftUI GroupBox. (`NSCoreHostingView<AppKitBoxView>` IIRC)
        ///     - This code is closely based off of disassembly of `-[_NSBoxMaterialCapableCustomView _updateSubviews]` (On Tahoe Beta 8, [Aug 2025])
        ///         - `_NSBoxMaterialCapableCustomView` is the custom view that draws the NSBox's appearance, when .boxType is NSCustomBox and the color is one that activates wallpaper tinting on NSBox like `.controlBackgroundColor`. `_NSBoxMaterialCapableCustomView` uses an `NSVisualEffectView` to achieve the tinting, just like we do here.
        
        if (self.subviews(withIdentifier: "MFDesktopTintingView").count == 0)
        {
            let effectView: NSView
            if (true) {
                effectView = NSVisualEffectView()
                (effectView as! NSVisualEffectView).material = NSVisualEffectView.Material.windowBackground /// [Aug 2025] `-[_NSBoxMaterialCapableCustomView _updateSubviews]` used `-[NSColor _getSemanticallyEquivalentVisualEffectMaterial:]`, but we define the `NSVisualEffectViewMaterial` directly.
            }
            else {
                /// TODO: Delete this (Testing code for setting if our corners line up)
                effectView = NSView()
                effectView.wantsLayer = true
                effectView.layer?.backgroundColor = NSColor.white.cgColor
            }
            
            effectView.identifier = NSUserInterfaceItemIdentifier("MFDesktopTintingView")
            effectView.autoresizingMask = [.width, .height]
            effectView.wantsLayer = true
            effectView.layer?.masksToBounds = true
            
            /// Make the `NSVisualEffectView` outline match the `NSBox` exactly, so the shaddow looks like it belongs to the `NSBox`
            ///     Also see `[RemapTableController viewDidLoad]` – In MMF 2, the RemapTable had to line up exactly with an NSBox surrounding it – so some of the same knowledge about NSBox sizes should be encoded there.
            
            effectView.layer?.cornerRadius = MFNSBoxCornerRadius()
            
            if #available(macOS 26.0, *) {
                effectView.frame = self.bounds
                effectView.layer?.cornerCurve = .continuous
            } else if #available(macOS 11.0, *) {
                effectView.frame = self.bounds.offsetBy(dx: 0, dy: 1).insetBy(dx: 3, dy: 3) /// [Aug 2025] Trivia: These weird insets only appear on NSPrimaryBox, not NSCustomBox [Aug 2025]
            } else {
                effectView.frame = self.bounds.offsetBy(dx: 0, dy: 1).insetBy(dx: 3, dy: 3) /// [Aug 2025] Not sure if pixel perfect but MMF 3 looks crappy pre-Big Sur anyways.
            }
            
            self._directlyAddSubview(effectView, positioned: .below, relativeTo: nil)
        }
    }
    
    /// Visual FX
    
    func hoverEffect(enable: Bool, playAcceptAnimation: Bool = false) {
        /// Ideas: Draw focus ring or shadow, or zoom

        /// Debug

        DDLogDebug("FIELD HOOVER: \(enable)")

        /// Init
        self.wantsLayer = true
        self.layer?.transform = CATransform3DIdentity
        self.coolSetAnchorPoint(anchorPoint: .init(x: 0.5, y: 0.5))

        if !enable {

            
            /// Animation curve
            
            let animation       = CASpringAnimation(speed: 2.25, damping: 1.0)
            let bounceAnimation = CASpringAnimation(speed: 3.75, damping: 0.25, initialVelocity: -10)
            let transformAnimation = playAcceptAnimation ? bounceAnimation : animation
            
            /// Make shadow animation.
            ///     [Aug 2025] We used to just use the transformAnimation as the shadowAnimation.
            ///     However, on some macOS versions, the overshoot caused visual glitches:
            ///         - Pre-Ventura, having overshoot in the shadow animation causes visual glitches
            ///         - [Aug 2025] the pre-Ventura glitches seem to be back – in macOS 15.5 Sequoia, on my 2018 Intel Mac Mini
            ///             (I haven't tested if the glitches occur on macOS 14, too)
            ///         - [Aug 2025] the pre-Ventura glitches are gone again – In macOS 26 Tahoe Beta 5, on my M1 MBA
            ///
            ///     Solutions we tried:
            ///         - Always use the `animation` instead of the `bounceAnimation` for the shadow to prevent overshoot.
            ///             > But that animation only removes the shadow shortly *after* the addField 'hits the ground', which looks a bit weird.
            ///         - Always use the`bounceAnimation` for the shadow, but put a 'clamp' on it  to keep it from overshooting.
            ///             - CoreAnimation doesn't let you do that. The CAAnimation objects are only parameter-holders for algorithms that run somewhere deep inside the CoreAnimation framework. (In a different process I think) (Might be wrong about this)
            ///             - The most customization you get is using a CASpringAnimation or CAMediaTimingFunction (cubic bezier). CAKeyFrameAnimation requires you to create an object for every keyframe. None of these are suited to creating a completely customized animation curve that could do something like 'clamping'.  (Might be wrong about all of this)
            ///             - Did a slight bit of reverse engineering on CASpringAnimation:
            ///                 CASpringAnimation seems to be copied into a C++ struct/class (`CA::Render::SpringAnimation::SpringAnimation()`) before actually being queried. The copying happens in `-[CASpringAnimation _copyRenderAnimationForLayer:]` and `-[CASpringAnimation _setCARenderAnimation:layer:]
            ///         - Measure the time when the animation first overshoots and create a shadow animation based on that.
            ///             > This is what we're using as of [Aug 2025]
            ///     Other solution ideas:
            ///         - Perhaps we could've removed the visual glitches without removing the overshoot.
            ///             > It's a bit weird how we're animating the shadow out by setting `NSShadow.clearShadow`, and I think that also interacts in complex ways with our `ReactiveAnimatorPropertyProxy`. Maybe the problem lies somewhere in there.
            ///         - Use CVDisplayLink
            ///             - This gives us full control over the animation, but loses the optimizations that CAAnimation claims (Doing the animations in the 'hardware' instead of the 'software'. See:  Core Animation Programming Guide > Core Animation Basics) (I have some reason to doubt that this matters)
            
            var shadowAnimation: CABasicAnimation
            do {
                if transformAnimation == animation {
                    if (true) { shadowAnimation = transformAnimation }
                    else      { shadowAnimation = CABasicAnimation(name: .linear, duration: transformAnimation.duration) } /// [Aug 2025] When we do this, the non-bouncy zoom-out animation of the addField seems much longer. (macOS 15.5, 2018 Mac Mini) Not sure what's going on. Perhaps getting `transformAnimation.duration` modifies the animation?
                }
                else if transformAnimation == bounceAnimation {
                    var firstOvershootTime = -1.0;
                    let framesPerSecond = 60;
                    let samplesPerFrame = 10;
                    let samplesPerSecond = Int32(framesPerSecond * samplesPerFrame) /// [Aug 2025] Making this many samples feels slow, but I think it's actually fast. To optimize I think we could lower the number of samples (haven't looked into when quality drops off), only calculate the samples up to the first overshoot, or reuse the transition-point-finder algorithm from BezierHybridCurve
                    let samples = MFCABasicAnimation_Sample(transformAnimation, samplesPerSecond)
                    
                    for (i, sample) in samples.enumerated() {
                        if sample.doubleValue >= 1.0 {
                            firstOvershootTime = Double(i) / Double(samplesPerSecond)
                            break
                        }
                    }
                    if firstOvershootTime != -1.0 {
                        shadowAnimation = CABasicAnimation(name: .linear, duration: firstOvershootTime)
                    }
                    else {
                        assert(false)
                        shadowAnimation = CABasicAnimation(name: .linear, duration: transformAnimation.duration) /// [Aug 2025] We only hit this case if it turns out the weird private stuff inside `MFCABasicAnimation_Sample()` is not portable and it fails.
                    }
                }
                else { fatalError() }
            }
            
            /// Play animation
            
            Animate.with(transformAnimation) {
                self.reactiveAnimator().layer.transform.set(CATransform3DIdentity)
            }
            Animate.with(shadowAnimation) {
                
//                var isDarkMode = false
//                if #available(macOS 10.14, *) {
//                    isDarkMode = (NSApp.effectiveAppearance == .init(named: .darkAqua)!)
//                }
//                let baseShadow = NSShadow() /// NSShadow.clearShadow
//                baseShadow.shadowColor = .shadowColor.withAlphaComponent(isDarkMode ? 0.75 : 0.225)
//                baseShadow.shadowOffset = NSMakeSize(0, 0)
//                baseShadow.shadowBlurRadius = 0.0
                
                self.reactiveAnimator().shadow.set(NSShadow.clearShadow)
            }
            

            /// Play tint animation

            if #available(macOS 10.14, *) {
                if playAcceptAnimation {
                    Animate.with(CASpringAnimation(speed: 3.5, damping: 1.0)) {
                        plusIconView.reactiveAnimator().contentTintColor.set(NSColor.controlAccentColor)
                    } onComplete: {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: { /// This 'timer' is not terminated when unhover is triggered some other way, leading to slightly weird behaviour
                            Animate.with(CASpringAnimation(speed: 3.5, damping: 1.3)) {
                                self.plusIconView.reactiveAnimator().contentTintColor.set(self.plusIconViewBaseColor())
                            }
                        })
                    }
                } else { /// Normal un-hovering
                    Animate.with(CASpringAnimation(speed: 3.5, damping: 1.3)) {
                        self.plusIconView.reactiveAnimator().contentTintColor.set(self.plusIconViewBaseColor())
                    }
                }
            }


        } else {

            /// Setup addField shadow

            var isDarkMode = checkDarkMode()

            let s = NSShadow()
            if #available(macOS 26.0, *) {
                s.shadowColor = .shadowColor.withAlphaComponent(isDarkMode ? 0.75 : 0.125) /// [Aug 2025] lighten the shadow on Tahoe since everything's lighter. TODO: Play around a little bit to perfect it.
                s.shadowOffset = .init(width: 0, height: -2)
                s.shadowBlurRadius = 1.5
            }
            else {
                s.shadowColor = .shadowColor.withAlphaComponent(isDarkMode ? 0.75 : 0.225)
                s.shadowOffset = .init(width: 0, height: -2)
                s.shadowBlurRadius = 1.5
            }

            self.wantsLayer = true
            self.layer?.masksToBounds = false
            self.superview?.wantsLayer = true
            self.superview?.layer?.masksToBounds = false

            /// Setup plusIcon shadow

            let t = NSShadow()
            t.shadowColor = .shadowColor.withAlphaComponent(0.5)
            t.shadowOffset = .init(width: 0, height: -1)
            t.shadowBlurRadius = /*3*/10

            plusIconView.wantsLayer = true
            plusIconView.layer?.masksToBounds = false
            plusIconView.superview?.wantsLayer = true
            plusIconView.superview?.layer?.masksToBounds = false

            /// Animate

            Animate.with(CASpringAnimation(speed: 3.75, damping: 1.0)) {
                self.reactiveAnimator().layer.transform.set(CATransform3DTranslate(CATransform3DMakeScale(1.005, 1.005, 1.0), 0.0, 1.0, 0.0))
                self.reactiveAnimator().shadow.set(s)
            }

//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: {
//                Animate.with(CABasicAnimation(name: .default, duration: 0.25)) {
//                    self.plusIconView.reactiveAnimator().shadow.set(t)
//                }
//            })
        }
    }
    
    private func checkDarkMode() -> Bool {
        
        if #available(macOS 10.14, *) {
            let isDarkMode = (NSApp.effectiveAppearance == .init(named: .darkAqua)!)
            return isDarkMode
        }
        return false
    }
    
}
