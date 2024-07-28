//
// --------------------------------------------------------------------------
// AddField.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Cocoa

@objc class AddField: NSBox {

    /// Storage
    
    @IBOutlet var plusIconView: NSImageView!
    
    /// Drawing
    ///     Overriding draw() breaks desktop tinting even if we just call super.draw()
    
//    override func draw(_ dirtyRect: NSRect) {
//        super.draw(dirtyRect)
//
//        // Drawing code here.
//    }
    
    var appearanceObservation: NSKeyValueObservation? = nil
    
    func coolInit() {
        
        /// Override icon on older macOS
        /// Explanation: We bundle an svg fallback for the SFSymbol that is used by default, but the resolution is wayy to low it's rendered too large. Maybe there's a more elegant solution but this should work.
        /// Notes:
        /// - Actually maybe we should just use NSAddTemplate in the first place even on newer macOS?
        /// - I think this makes it unnecessary that we bundle the svg fallback for the 'add' SFSymbol
        
        if #available(macOS 11.0, *) { } else {
            plusIconView.image = NSImage(named: NSImage.addTemplateName)
        }
        
        /// Fix hover animations
        ///     Need to set some shadow before (and not directly, synchronously before) the hover animation first plays. No idea why this works
        self.shadow = .clearShadow
        plusIconView.shadow = .clearShadow
        
        /// Make colors non-transparent
        updateColors()
        
        /// Observe darkmode changes to update colors (we do the same thing in RemapTable)
        if #available(macOS 10.14, *) {
            appearanceObservation = NSApp.observe(\.effectiveAppearance) { nsApp, change in
                self.updateColors()
            }
        }
    }
    
    func updateColors() {
        
        /// We use non-transparent colors so the shadows don't bleed through
        
        /// Init
        self.wantsLayer = true
        
        /// Check darkmode
        let isDarkMode = checkDarkMode()
        
//        /// Get baseColor
//        let baseColor: NSColor = isDarkMode ? .black : .white
//
//        /// Define baseColor blending fractions
//        let fillFraction = isDarkMode ? 0.1 : 0.25
//        let borderFraction = isDarkMode ? 0.1 : 0.25
        
        ///
        /// Update fillColor
        /// - This is reallly just quarternaryLabelColor but without transparency. Edit: We're making it a little lighter actually.
        /// - I couldn't find a nicer way to remove transparency except hardcoding it. Our solidColor methods from NSColor+Additions.m didn't work properly. I suspect it's because the NSColor objects can represent different colors depending on which context they are drawn in.
        /// - Possible nicer solution: I think the only dynamic way to remove transparency that will be reliable is to somehow render the view in the background and then take a screenhot
        /// - Other possible solution: We really want to do this so we don't see the NSShadow behind the view. Maybe we could clip the drawing of the shadow, then we wouldn't have to remove transparency at all.
        /// - Update:
        ///     - I tried lots of different approaches for this and finally found one that I'm confident should work, but it's really annoying to implement and I gave up on it. See these experiments in the (reverted) commit 35742760e0bb0c126e16183f11f65532953822cb
        ///     - Instead we're just using systemColors now. So much easier! Even if the darkmode colors aren't quite as nice.

        
        /// v New systemColor approach
        /// Notes:
        /// - Using systemColors now to properly support desktop tinting. (Can't use transparent colors because of the NSShadow on hover)
        /// - .underPageBackgroundColor is not semantic but it looks perfect.
        /// - I found these colors that support tinting (found them by searching for 'background', maybe there are more):
        ///   - .controlBackgroundColor, .textBackgroundColor, .underPageBackgroundColor, .windowBackgroundColor
        ///   - .controlBackgroundColor looks good while tinting, but is too dark otherwise. .textBackgroundColor is the same. .underPageBackgroundColor is even darker. -> best choice is .windowBackgroundColor
        
        if isDarkMode {
            self.fillColor = .windowBackgroundColor ///.controlBackgroundColor
        } else {
            self.fillColor = .underPageBackgroundColor
        }
        
        /// v Old solidColor approach
        
//        var quarternayLabelColor: NSColor
//        if isDarkMode {
//            quarternayLabelColor = NSColor(red: 57/255, green: 57/255, blue: 57/255, alpha: 1.0)
//        } else {
//            quarternayLabelColor = NSColor(red: 227/255, green: 227/255, blue: 227/255, alpha: 1.0)
//        }
//
//        self.fillColor = quarternayLabelColor.blended(withFraction: fillFraction, of: baseColor)!
        
        ///
        /// Update borderColor
        ///

        /// v New systemColor approach
        ///     Using systemColors now to properly support desktop tinting. Also the transparency isn't an issue at all here, not sure why we hardcoded the colors in the first place
        
        if #available(macOS 10.14, *) {
            self.borderColor = .separatorColor
        } else {
            self.borderColor = .gridColor
        }
        
        /// v Old solidColor approach
        /// This is really just .separatorColor without transparency
        
//        let separatorColor: NSColor
//        if isDarkMode {
//            separatorColor = NSColor(red: 77/255, green: 77/255, blue: 77/255, alpha: 1.0)
//        } else {
//            separatorColor = NSColor(red: 198/255, green: 198/255, blue: 198/255, alpha: 1.0)
//        }
//
//        self.borderColor = separatorColor.blended(withFraction: borderFraction, of: baseColor)!
        
        /// Make border thicker in darkmode
        ///     Since the addField is now the same color as the windowBackground in darkmode we want to give it more visual presence this way
        
        if isDarkMode {
            self.borderWidth = 1.5
        } else {
            self.borderWidth = 1.0
        }
        
        /// Update plusIcon color
        if #available(macOS 10.14, *) {
            plusIconView.contentTintColor = plusIconViewBaseColor()
        }
        
        /// Testing
        ///     Doesn't seem to change anything
        self.needsDisplay = true
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
            
            let animation = CASpringAnimation(speed: 2.25, damping: 1.0)
            let bounceAnimation = CASpringAnimation(speed: 3.75, damping: 0.25, initialVelocity: -10)
            
            let transformAnimation = playAcceptAnimation ? bounceAnimation : animation
            let shadowAnimation: CAAnimation
            if #available(macOS 13.0, *) {
                shadowAnimation = transformAnimation
            } else {
                /// Pre-Ventura, having overshoot in the shadow animation causes visual glitches
                shadowAnimation = animation
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
            s.shadowColor = .shadowColor.withAlphaComponent(isDarkMode ? 0.75 : 0.225)
            s.shadowOffset = .init(width: 0, height: -2)
            s.shadowBlurRadius = 1.5

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
    
    private func plusIconViewBaseColor() -> NSColor {
        
        return NSColor.systemGray
    }
    
    private func checkDarkMode() -> Bool {
        
        if #available(macOS 10.14, *) {
            let isDarkMode = (NSApp.effectiveAppearance == .init(named: .darkAqua)!)
            return isDarkMode
        }
        return false
    }
    
}
