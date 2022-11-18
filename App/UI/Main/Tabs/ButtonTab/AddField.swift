//
// --------------------------------------------------------------------------
// AddField.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa
import CocoaLumberjackSwift

// MARK: - AddField

@objc class AddField: NSBox, CALayerDelegate {

    /// Storage
    
    @IBOutlet var plusIconView: NSImageView!
//    fileprivate var shadowView: ShadowView?
    @objc var coolShadow: NSShadow = NSShadow()
    
    /// Custom drawing
    
//    func draw(_ layer: CALayer, in ctx: CGContext) {
//        /// CALayerDelegate drawing method
//    }
    
//    override func draw(_ dirtyRect: NSRect) {
//
//        /// NSView drawing method
//        ///     Overriding this and just calling super disables all drawing?? ... Except if we create a custom backing layer or sth
//
//
//        let ctx = NSGraphicsContext.current?.cgContext
//
//        /// Let super draw to image
//
//        let mask = NSImage(size: dirtyRect.size, flipped: false) { rect in
//
////            NSColor.green.setFill()
////            self.coolShadow!.set()
//
//
//
////            rect.insetBy(dx: self.shadowBuffer, dy: self.shadowBuffer).fill()
//
//            super.draw(rect)
//
//            return true
//        }
//
//        /// Draw image to screen with shadow
//
//        let s = NSShadow()
//        s.shadowColor = .shadowColor
//        s.shadowOffset = .zero
//        s.shadowBlurRadius = 5.0
////        s.set()
////        NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 5.0)
//        self.shadow = s
//
//        super.draw(dirtyRect)
//
//
//
//        ctx?.addRect(.infinite)
////        mask.
//
//
//        mask.draw(in: dirtyRect, from: dirtyRect, operation: .sourceOver, fraction: 1.0)
//    }
    
    /// Init
    
    var appearanceObservation: NSKeyValueObservation? = nil
    
    func coolInit() {
        
        super.wantsLayer = true
        super.layer?.masksToBounds = false
        self.wantsLayer = true
        self.layer?.masksToBounds = false
        
        
        
        
        
        
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
        
        /// Init layers for hoverEffect
        
        self.wantsLayer = true
        self.layer?.masksToBounds = false
        self.superview?.wantsLayer = true
        self.superview?.layer?.masksToBounds = false
        
        plusIconView.wantsLayer = true
        plusIconView.layer?.masksToBounds = false
        plusIconView.superview?.wantsLayer = true
        plusIconView.superview?.layer?.masksToBounds = false
        
        /// Custom layer stuff
        ///  Setting canDrawSubviewsIntoLayer false is necessary so that drawing happens in the layer instead of the view (but customizing the drawing in the layer also doesn't work...)
        self.canDrawSubviewsIntoLayer = false
        
        /// Invert
        
        
        var mask: CALayer
        do {
//            mask = try NSKeyedUnarchiver.unarchivedObject(ofClass: CALayer.self, from: try NSKeyedArchiver.archivedData(withRootObject: self.layer as Any, requiringSecureCoding: false)) ?? CALayer()
            mask = CALayer()
        } catch {
            mask = CALayer()
        }
//        let shadowSpread = 10.0
//        mask.frame = mask.frame.insetBy(dx: -shadowSpread, dy: -shadowSpread).offsetBy(dx: shadowSpread/2.0, dy: shadowSpread/2.0)
//        self.layer?.mask = mask
    
        
        
//        shadowView = ShadowView(targetView: self)
//        shadowView!.coolShadow = NSShadow()
//        shadowView!.coolShadow?.shadowColor = .shadowColor
//        shadowView!.coolShadow?.shadowOffset = NSSize(width: 0.0, height: -0.1)
//        shadowView!.coolShadow?.shadowBlurRadius = 5.0
//
//        shadowView!.frame = self.frame
//
//        self.superview!.addSubview(shadowView!)
//
//        shadowView!.needsDisplay = true
        
        
        
        
        
        
        
        
        /// Make colors non-transparent
        updateColors()
        
        /// Observe darkmode changes to update colors (we do the same thing in RemapTable)
        if #available(macOS 10.14, *) {
            appearanceObservation = NSApp.observe(\.effectiveAppearance) { nsApp, change in
                self.updateColors()
            }
        }
    }
    
//    override func makeBackingLayer() -> CALayer {
//        let layer = AddFieldLayer()
//        layer.delegate = self
//        return layer
//    }
//
//    override var wantsUpdateLayer: Bool {
//        /// Make it so drawing is done in the layer
//        assert(!canDrawSubviewsIntoLayer) /// Other
//        return true
//    }
    
    func updateColors() {
        
        /// We use non-transparent colors so the shadows don't bleed through
        
        /// Check darkmode
        let isDarkMode = getIsDarkMode()
        
        /// Get baseColor
        let baseColor: NSColor = isDarkMode ? .black : .white
        
        /// Define baseColor blending fractions
        let fillFraction = isDarkMode ? 0.1 : 0.25
        let borderFraction = isDarkMode ? 0.1 : 0.25
        
        /// Update fillColor
        ///     This is reallly just quarternaryLabelColor but without transparency. Edit: We're making it a little lighter actually.
        ///     I couldn't find a nicer way to remove transparency except hardcoding it. Our solidColor methods from NSColor+Additions.m didn't work properly. I suspect it's because the NSColor objects can represent different colors depending on which context they are drawn in.
        ///     Possible nicer solution: I think the only dynamic way to remove transparency that will be reliable is to somehow render the view in the background and then take a screenhot
        ///     Other possible solution: We really want to do this so we don't see the NSShadow behind the view. Maybe we could clip the drawing of the shadow, then we wouldn't have to remove transparency at all.
        
//        var quaternayLabelColor: NSColor
//        if isDarkMode {
//            quarternayLabelColor = NSColor(red: 57/255, green: 57/255, blue: 57/255, alpha: 1.0)
//
//
//
////            quarternayLabelColor = quarternayLabelColor.withAlphaComponent(0.50) /// Make things a tiny bit transparent so that desktop tinting looks better
//
//
//
//        } else {
//            quarternayLabelColor = NSColor(red: 227/255, green: 227/255, blue: 227/255, alpha: 1.0)
//        }
        var fillColor: NSColor
        if #available(macOS 10.14, *) {
            if isDarkMode {
                fillColor = NSColor.quaternaryLabelColor.withAlphaComponent(NSColor.quaternaryLabelColor.alphaComponent / 2.0)
//                fillColor = .placeholderTextColor
            } else {
                fillColor = NSColor.quaternaryLabelColor.withAlphaComponent(NSColor.quaternaryLabelColor.alphaComponent / 3.0)
            }
        } else {
            fillColor = .black
            // Fallback on earlier versions
        }//.blended(withFraction: fillFraction, of: baseColor)!
        
        if isDarkMode {
            fillColor = .controlBackgroundColor
        } else {
            fillColor = .underPageBackgroundColor
        }
//        fillColor =  //.controlBackgroundColor //.textBackgroundColor //.underPageBackgroundColor // .windowBackgroundColor

        
        self.fillColor = fillColor //quarternayLabelColor.blended(withFraction: fillFraction, of: baseColor)!
        
        /// Update borderColor
        ///     This is really just .separatorColor without transparency
        
        let separatorColor: NSColor
        if isDarkMode {
            separatorColor = NSColor(red: 77/255, green: 77/255, blue: 77/255, alpha: 1.0)
        } else {
            separatorColor = NSColor(red: 198/255, green: 198/255, blue: 198/255, alpha: 1.0)
        }
        
        let borderColor: NSColor
//        if #available(macOS 10.14, *) {
//            borderColor = NSColor.separatorColor.blended(withFraction: borderFraction, of: baseColor)!
//        } else {
//            borderColor = NSColor.black
//        }
        if #available(macOS 10.14, *) {
            borderColor = .separatorColor
        } else {
            borderColor = .gridColor
        }
        
        self.borderColor = borderColor//.blended(withFraction: borderFraction, of: baseColor)!
        
        /// Update plusIcon color
        if #available(macOS 10.14, *) {
            plusIconView.contentTintColor = plusIconViewBaseColor()
        }
    }
    
    /// Visual FX
    
    func hoverEffect(enable: Bool, playAcceptAnimation: Bool = false) {
        /// Ideas: Draw focus ring or shadow, or zoom
        
        
//        shadowView!.coolInit()
        
//        let coolShadow = NSShadow()
//        coolShadow?.shadowColor = NSColor.shadowColor
//        coolShadow?.shadowOffset = NSSize(width: 0.0, height: -0.1)
//        coolShadow?.shadowBlurRadius = 5.0
//
//        frame = self.frame

//        self.addSubview(shadowView)

//        shadowView!.needsDisplay = true
        
        
//        shadowView.needsDisplay = true
        
        
        
        
        
        
        
        /// Debug

        DDLogDebug("FIELD HOOVER: \(enable)")

        self.layer?.transform = CATransform3DIdentity
        self.coolSetAnchorPoint(anchorPoint: .init(x: 0.5, y: 0.5))

        if !enable {


            /// Animation curve
            var animation = CASpringAnimation(speed: 2.25, damping: 1.0)

            if playAcceptAnimation {
                animation = CASpringAnimation(speed: 3.75, damping: 0.25, initialVelocity: -10)
            }


            /// Play animation

            Animate.with(animation) {
                self.reactiveAnimator().layer.transform.set(CATransform3DIdentity)
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

            var isDarkMode = getIsDarkMode()

            let s = NSShadow()
            s.shadowColor = .shadowColor.withAlphaComponent(isDarkMode ? 0.75 : 0.225)
            s.shadowOffset = .init(width: 0, height: -2)
            s.shadowBlurRadius = 1.5


            /// Setup plusIcon shadow

//            let t = NSShadow()
//            t.shadowColor = .shadowColor.withAlphaComponent(0.5)
//            t.shadowOffset = .init(width: 0, height: -1)
//            t.shadowBlurRadius = /*3*/10
//
//            if let l = self.layer {
//
//                self.needsLayout = true
//                self.window?.layoutIfNeeded()
//                self.window?.contentView?.layoutSubtreeIfNeeded()
//
//                let cr = self.cornerRadius
//                let ofs = t.shadowOffset
//                let ins1 = max(abs(ofs.width), abs(ofs.height)) + 1
//                let ins2 = 0.0 //-t.shadowBlurRadius
//
//                let outerPath = NSBezierPath(cgPath: CGPath(roundedRect: l.bounds.insetBy(dx: ins2, dy: ins2), cornerWidth: cr - ins2/2.0, cornerHeight: cr - ins2/2.0, transform: nil))
//
//                let innerPath = NSBezierPath(cgPath: CGPath(roundedRect: l.bounds.insetBy(dx: ins1, dy: ins1).offsetBy(dx: -ofs.width, dy: -ofs.height), cornerWidth: cr - ins1/2.0, cornerHeight: cr - ins1/2.0, transform: nil))
//
//                outerPath.append(innerPath.reversed)
//                self.layer?.shadowPath = outerPath.cgPath
//
//            }
            
            
            
            
            
            /// Animate

            Animate.with(CASpringAnimation(speed: 3.75, damping: 1.0)) {
                self.reactiveAnimator().layer.transform.set(CATransform3DTranslate(CATransform3DMakeScale(1.005, 1.005, 1.0), 0.0, 1.0, 0.0))
                self.reactiveAnimator().shadow.set(s)
            }
        }
        
        
        
        
        
        
        


    }
    
    private func plusIconViewBaseColor() -> NSColor {
        
        return NSColor.systemGray
    }
    
    private func getIsDarkMode() -> Bool {
        
        if #available(macOS 10.14, *) {
            let isDarkMode = (NSApp.effectiveAppearance == .init(named: .darkAqua)!)
            return isDarkMode
        }
        return false
    }
    
    
    
    
    
    
    
    
    override var wantsDefaultClipping: Bool { false }
    
}

// MARK: - ShadowView

//@objc fileprivate class ShadowView: NSView, CALayerDelegate {
//
//    @objc var coolShadow: NSShadow?
//    let shadowBuffer = 50.0
//    var targetView: NSView
//
//    init(targetView: NSView) {
//
//        self.targetView = targetView
//
//
//        super.init(frame: .zero)
//
//        self.frame = targetView.frame.insetBy(dx: -shadowBuffer, dy: -shadowBuffer)
//
//        self.targetView = targetView
//
//
//        super.wantsLayer = true
//        super.layer?.masksToBounds = false
//
//        self.wantsLayer = true
//        self.layer?.masksToBounds = false
////        self.layer = ShadowBackingLayer()
//
//        self.layer?.shadowColor = .clear
//
//
//    }
//
//
//    override init(frame frameRect: NSRect) {
//        self.targetView = NSView()
//        super.init(frame: frameRect)
//    }
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//
//    override var wantsDefaultClipping: Bool {
//        return false
//    }
//
////    override func makeBackingLayer() -> CALayer {
////        let layer = ShadowBackingLayer()
////        layer.delegate = self
////        return layer
////    }
//
//    override func draw(_ dirtyRect: NSRect) {
//        super.draw(dirtyRect)
////
//        let ctx = NSGraphicsContext.current?.cgContext
////        ctx?.saveGraphicsState()
//
////        let thing = NSBezierPath(roundedRect: dirtyRect, xRadius: 10.0, yRadius: 10.0)
//
//
////        let path = NSBezierPath(rect: dirtyRect).cgPath
////        let insetPath = NSBezierPath(rect: dirtyRect.insetBy(dx: 50, dy: 50)).cgPath
////        let outsetPath = NSBezierPath(rect: dirtyRect.insetBy(dx: -10, dy: -10)).cgPath
//
//
//
//
//        /// Draw shadow
//
//
//        self.layer?.shadowColor = .clear
//
//
//        let fullShadow = NSShadow()
//        fullShadow.shadowColor = .blue
//        fullShadow.shadowOffset = .zero
//        fullShadow.shadowBlurRadius = 5.0
//
//
//        /// Cache to image
//
//        let mask = NSImage(size: dirtyRect.insetBy(dx: -shadowBuffer, dy: -shadowBuffer).size, flipped: false) { rect in
//
//            NSColor.green.setFill()
//            self.coolShadow!.set()
//
//            rect.insetBy(dx: self.shadowBuffer, dy: self.shadowBuffer).fill()
//
//            return true
//        }
//
////        let imageCG = ctx!.makeImage()!
////        let mask = NSImage(cgImage: imageCG, size: NSSize(width: imageCG.width, height: imageCG.height))
////
////        ctx?.addRect(.infinite)
////        ctx?.addRect(dirtyRect.insetBy(dx: 0, dy: 0))
////        ctx?.clip(using: .evenOdd)
//
////        NSShadow.clearShadow.set()
//
////        let sizeDiff = NSSize(width: dirtyRect.width - mask.size.width, height: dirtyRect.height - mask.size.height)
//
//        ctx?.resetClip()
//        let imageDrawingRect = dirtyRect.insetBy(dx: -shadowBuffer-20, dy: -shadowBuffer-20)
//        mask.draw(in: imageDrawingRect, from: .zero, operation: .sourceOver, fraction: 1.0)
//
//
////        let maskCG = mask.cgImage(forProposedRect: nil, context: NSGraphicsContext.current!, hints: nil)!
//
//
////        let maskReconst = NSImage(cgImage: maskCG, size: dirtyRect.size)
//
////        let ctx = NSGraphicsContext.current!.cgContext
//
////        ctx.saveGState()
////        ctx.addRect(ctx.boundingBoxOfClipPath)
////        ctx.addPath(insetPath)
////        ctx.clip(to: dirtyRect, mask: maskCG)
//
//
//
////        NSColor.blue.setFill()
////        ctx.setShadow(offset: CGSize(width: -1, height: -1), blur: shadow!.shadowBlurRadius, color: shadow!.shadowColor!.cgColor)
////        ctx.addPath(path)
////        ctx.fillPath()
//
//
////        ctx.addPath(path)
////        ctx.setShadow(offset: CGSize(width: 1, height: 1), blur: shadow!.shadowBlurRadius, color: shadow!.shadowColor!.cgColor)
////        ctx.setBlendMode(.normal)
////        ctx.fillPath()
////
////        ctx.addPath(path)
////        ctx.setShadow(offset: CGSize(width: -1, height: -1), blur: shadow!.shadowBlurRadius, color: shadow!.shadowColor!.cgColor)
////        ctx.setBlendMode(.normal)
////        ctx.fillPath()
////        ctx.restoreGState()
//
////        ctx?.cgContext.clip(to: dirtyRect)
////        ctx?.cgContext.clip(using: .evenOdd)
////        NSBezierPath(rect: dirtyRect).addClip()
//
//
//
////        NSColor.red.set()
////        NSShadow.clearShadow.set()
//
////        ctx?.restoreGraphicsState()
//    }
//
////    override var isOpaque: Bool {
////        true
////    }
//
//}
//
//@objc fileprivate class ShadowBackingLayer: CALayer {
//
//
//    override var masksToBounds: Bool {
//        get {
//            false
//        }
//        set {
//
//        }
//    }
//
////    override func draw(in ctx: CGContext) {
////        /// Don't draw shadow
////        self.shadowColor = .clear
////        super.draw(in: ctx)
////    }
//
//}

// MARK: - AddFieldLayer

//@objc fileprivate class AddFieldLayer: CALayer {
//
//    override func draw(in ctx: CGContext) {
//
//        /// This is currently called, but not calling super doesn't seem to change anything
//
//        self.shadowOpacity = 0.0
//    }
//
//}

// MARK: - Extend NSBezierPath

extension NSBezierPath {
    // https://stackoverflow.com/a/39385101
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        for i in 0 ..< self.elementCount {
            let type = self.element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo: path.move(to: points[0])
            case .lineTo: path.addLine(to: points[0])
            case .curveTo: path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath: path.closeSubpath()
            @unknown default: fatalError("Unknown element \(type)")
            }
        }
        return path
    }

    // https://stackoverflow.com/a/49011112
    convenience init(cgPath: CGPath) {
        self.init()
        cgPath.applyWithBlock { (elementPointer: UnsafePointer<CGPathElement>) in
            let element = elementPointer.pointee
            let points = element.points
            switch element.type {
            case .moveToPoint:
                self.move(to: points.pointee)
            case .addLineToPoint:
                self.line(to: points.pointee)
            case .addQuadCurveToPoint:
                let qp0 = self.currentPoint
                let qp1 = points.pointee
                let qp2 = points.successor().pointee
                let m = 2.0/3.0
                let cp1 = NSPoint(
                    x: qp0.x + ((qp1.x - qp0.x) * m),
                    y: qp0.y + ((qp1.y - qp0.y) * m)
                )
                let cp2 = NSPoint(
                    x: qp2.x + ((qp1.x - qp2.x) * m),
                    y: qp2.y + ((qp1.y - qp2.y) * m)
                )
                self.curve(to: qp2, controlPoint1: cp1, controlPoint2: cp2)
            case .addCurveToPoint:
                let cp1 = points.pointee
                let cp2 = points.advanced(by: 1).pointee
                let target = points.advanced(by: 2).pointee
                self.curve(to: target, controlPoint1: cp1, controlPoint2: cp2)
            case .closeSubpath:
                self.close()
            @unknown default:
                fatalError("Unknown type \(element.type)")
            }
        }
    }
}
