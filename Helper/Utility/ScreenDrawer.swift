//
// --------------------------------------------------------------------------
// Drawer.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Cocoa

@objc class ScreenDrawer: NSObject {
    /// This class can display graphics anywhere on the screen
    /// Based on https://developer.apple.com/library/archive/samplecode/FunkyOverlayWindow/Listings/FunkyOverlayWindow_OverlayWindow_m.html#//apple_ref/doc/uid/DTS10000391-FunkyOverlayWindow_OverlayWindow_m-DontLinkElementID_8
    
    
    /// Var - Singleton instance
    
    @objc static let shared = ScreenDrawer()
    
    /// Vars - init
    
    @objc var canvas: NSWindow = NSWindow()
    /// ^ Need to init this to NSWindow. (Up here not in init()) for things to work. Super strange.
    
    /// Init
    
    @objc func load_Manual() {
        
        /// Using  `load_Manual` instead of `init`. See PointerFreeze -> `load_Manual` for explanation
        
        /// Create canvas window
        
        canvas = Canvas.init(contentRect: NSRect.zero, styleMask: .borderless, backing: .buffered, defer: false, screen: nil)
        
        /// Configure canvas window

        canvas.backgroundColor = .clear
        canvas.isOpaque = false /// Make window transparent but content visible
        canvas.alphaValue = 1.0
        canvas.level = NSWindow.Level.init(Int(CGWindowLevelForKey(.cursorWindow)) + 1) /// Canvas draws above everything else
        canvas.ignoresMouseEvents = true /// Mouse events should pass through
        canvas.acceptsMouseMovedEvents = false /// Don't track mouse moving
        canvas.collectionBehavior = [.stationary, .moveToActiveSpace] /// Make unaffected by Mission Control and Exposé

        /// Set contentView
        canvas.contentView = CanvasContent()
        
        /// Attempts to fix issue where moving pointer causes CPU load when the canvas is displaying (Ventura Beta)
        ///     -> Doesn't work
        ///     If we fix this, we might also want to update `PointerFreeze.drawPuppetCursor()` to use the "efficient undraw" method
        
        canvas.acceptsMouseMovedEvents = false
        canvas.disableCursorRects()
        
        /// Optimization
        ///  Setting frame on canvas.contentView subview is really slow for some reason. We think it might be doing autolayout stuff even though we don't need that. Here are attempts at disabling autolayout stuff. We're also trying to disable autolayout in other places. I'm not sure if this works/improves performance.
    
        canvas.contentView?.translatesAutoresizingMaskIntoConstraints = false
        canvas.contentView?.autoresizingMask = .none
        canvas.contentView?.removeConstraints(canvas.contentView?.constraints ?? [])
        canvas.contentView?.autoresizesSubviews = false
    }
    
    /// Drawing
    
    @objc func draw(view: NSView, atFrame frameInScreen: NSRect, onScreen screen: NSScreen) {
        
        /// Optimization
        ///     Trying to disable autolayout. Not sure if this works/improves performance
        view.translatesAutoresizingMaskIntoConstraints = false
        view.autoresizingMask = .none
        view.removeConstraints(view.constraints)
        
        /// Begin transaction
        ///     Using transaction speeds things up slightly. Might be placebo.
        CATransaction.begin()
        
        /// Size `canvas` to fill `screen`
        canvas.setFrame(screen.frame, display: false)
        
        /// Get frame for drawing image in canvas
        let frameInCanvas = canvas.convertFromScreen(frameInScreen); /// The canvas window is exactly as large as the screen, but it's origin might be different. ()
        
        /// Debug
        DDLogDebug("screennnn: \(screen)")
        
        /// Set frame to imageView
        view.frame = frameInCanvas
        
        /// Add imageView to canvas
        canvas.contentView?.addSubview(view)
        
        /// Put canvas window on top or sth
        ///     This is necessary after switching spaces
        ///     Now that we're actually closing the window and not using the "efficient undraw" method, I saw some crashes with this. Might help to do this before the other stuff? TODO: Remove this comment if everything works.
        canvas.orderFront(nil)
        
        /// Commit transaction
        CATransaction.commit()
    }
    @objc func move(view: NSView, toOrigin newOrigin: NSPoint) {
        
        ///
        /// Validate
        ///
        
//        guard let canvas = canvas else { fatalError() }
        guard (view.superview!.isEqual(to: canvas.contentView)) else { fatalError() }
        /// ^ This crashes sometimes because view doesn't have a superview. This happens when scroll zooming and drag scrolling at the same time on the same button. Investigate.
        
        /// Translate screen -> canvas
        
        let newOrigin = canvas.convertPoint(fromScreen: newOrigin);
        
        ///
        /// Move
        ///
        /// Discussion:
        ///  - Sol 1 moves the view normally, it calls all sorts of autolayout stuff and is very slow. Can't manage to turn that off. Sol 2 uses transforms and is a little faster, but it still seems to call autolayout stuff for some reason. Update late 2023: We did some more stuff to turn off autolayout/constraints stuff, and then we tested sol 1 and sol 2 again, and now sol 1 is faster. However we also found that there might be some randomness factor in our testing (See https://developer.apple.com/forums/thread/743378?answerId=775077022#775077022) so our tests aren't really conclusive. So sol 1 seems to use less CPU now, however, sol 1 seems to introduce some input lag, so we're going with sol 2 still.
        
        /// Sol 1
        
//        view.setFrameOrigin(newOrigin)
        
        /// Sol 2
        
        view.wantsLayer = true
        let origin = view.frame.origin
        let transform = CGAffineTransform(translationX: newOrigin.x - origin.x, y: newOrigin.y - origin.y)
        view.layer?.setAffineTransform(transform)
    }
    
    @objc func undraw(view: NSView) {
        
        /// Guard view is drawn
        guard view.superview!.isEqual(to: canvas.contentView) else {
            fatalError("Idk dude Swift value semantics or sth uchh")
        }
        
        /// Debug
//        DDLogDebug("Superview: \(view), canvas: \(canvas)")
        
        /// Remove view
        ///     Maybe we should just make it invisible instead?
        view.removeFromSuperview()
        
        /// Remove canvas
        ///     Also see other comments in this file containing "efficient undraw"
        canvas.isReleasedWhenClosed = false
        canvas.close()
        
        /// Update Canvas
        ///     Not necessary
//            canvas.displayIfNeeded()
            
    }
    
    @objc func flush() {
//        guard let canvas = canvas else { fatalError() }
//        canvas.orderOut(nil);
        canvas.contentView = CanvasContent()
    }
    
    
}

fileprivate class CanvasContent: NSView {
    
    // MARK: Pointer Move Optimization
    @objc override func hitTest(_ point: NSPoint) -> NSView? {
        /// Trying to remove CPU load when moving the pointer over canvas.
        ///     -> Doesn't work.
        return nil
    }
    
    // MARK: Autolayout Optimization
    /// Try to reduce CPU load when moving the content image. IIRC there is autolayout stuff taking up CPU, which we don't need but can't seem to disable. Update: Not sure if disabling autolayout stuff works/helps performance
    
    @objc override func layout() {
        return
    }
    @objc override func layoutSubtreeIfNeeded() {
        return
    }
    @objc override func updateConstraints() {
        super.updateConstraints() /// Need to call this, otherwise crash. Seems to only be called once (on startup) though.
        return
    }
    @objc override func updateConstraintsForSubtreeIfNeeded() {
        return
    }
    @objc override var needsLayout: Bool {
        get { false }
        set { return }
    }
    @objc override var needsUpdateConstraints: Bool {
        get { false }
        set { return }
    }
    override class var requiresConstraintBasedLayout: Bool {
        get { false }
        set { return }
    }
    
}

fileprivate class Canvas: NSWindow {
    
    
    override func mouseMoved(with event: NSEvent) {
//        DDLogError("Mouse MOVEDDD")
    }
    override func mouseDragged(with event: NSEvent) {
//        DDLogError("Mouse DRAGGEDDD")
    }
    override func mouseEntered(with event: NSEvent) {
//        DDLogError("Mouse ENTEREDDD")
    }
    override func mouseExited(with event: NSEvent) {
//        DDLogError("Mouse EXITEDDDD")
    }
//    override func layoutIfNeeded() {
    /// Developer docs say to not override this
//        return nil
//    }
}
