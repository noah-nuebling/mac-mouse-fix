//
// --------------------------------------------------------------------------
// Drawer.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa
import CocoaLumberjackSwift

@objc class ScreenDrawer: NSObject {
    /// This class can display graphics anywhere on the screen
    /// Based on https://developer.apple.com/library/archive/samplecode/FunkyOverlayWindow/Listings/FunkyOverlayWindow_OverlayWindow_m.html#//apple_ref/doc/uid/DTS10000391-FunkyOverlayWindow_OverlayWindow_m-DontLinkElementID_8
    
    
    /// Var - Singleton instance
    
    @objc static let shared = ScreenDrawer()
    
    /// Vars - init
    
    @objc let canvas: NSWindow
    
    /// Init
    
    @objc override init() {
        
        var canvasFrame = NSScreen.main?.frame
        if canvasFrame == nil {
            canvasFrame = NSRect.zero
        }
        
        canvas = NSWindow.init(contentRect: canvasFrame!, styleMask: .borderless, backing: .buffered, defer: false, screen: nil)
        
        canvas.isOpaque = false /// Make window transparent but content visible
        canvas.backgroundColor = .clear
        canvas.alphaValue = 1.0
        canvas.level = NSWindow.Level.init(Int(CGWindowLevelForKey(.cursorWindow)) + 1) /// Canvas draws above everything else
        canvas.ignoresMouseEvents = true /// Mouse events should pass through

        canvas.makeKeyAndOrderFront(nil)
        
        /// Optimization
        ///  Setting frame on canvas.contentView subview is really slow for some reason. Here are attempts at fixing that.
    
//        canvas.contentView?.translatesAutoresizingMaskIntoConstraints = false
//        canvas.contentView?.autoresizingMask = .none
//        canvas.contentView?.removeConstraints(canvas.contentView?.constraints ?? [])
//        canvas.contentView?.autoresizesSubviews = false
    }
    
    /// Drawing
    
    @objc func draw(view: NSView, atFrame frameInScreen: NSRect, onScreen screen: NSScreen) {
        
        /// Set props on view to (hopefully) optimize
//        view.translatesAutoresizingMaskIntoConstraints = false
//        view.autoresizingMask = .none
//        view.removeConstraints(view.constraints)
        
        /// Size `canvas` to fill `screen`
        canvas.setFrame(screen.frame, display: false)
        
        /// Get frame for drawing image in canvas
        let frameInCanvas = frameInScreen /// Don't need to use `convertFromScreen()` because the canvas window is exactly as large as the screen
        
        /// Set frame to imageView
        view.frame = frameInCanvas
        
        /// Add imageView to canvas
        canvas.contentView?.addSubview(view)
        
        /// Put canvas window on top or sth
        ///     This is necessary after switching spaces
        canvas.orderFront(nil)
    }
    @objc func move(view: NSView, toOrigin newOrigin: NSPoint) {
        
        guard (view.superview!.isEqual(to: canvas.contentView)) else { fatalError() }
        /// ^ This crashes sometimes because view doesn't have a superview. This happens when scroll zooming and drag scrolling at the same time on the same button. Investivate.
        
        /// Sol 1
        /// This calls all sorts of autolayout stuff and is very slow. Can't manage to turn that off
        
//        view.setFrameOrigin(newOrigin)
        
        /// Sol 2
        /// This is a little faster
        
        view.wantsLayer = true
        let origin = view.frame.origin
        let transform = CGAffineTransform(translationX: newOrigin.x - origin.x, y: newOrigin.y - origin.y)
        view.layer?.setAffineTransform(transform)
        
    }
    
    @objc func undraw(view: NSView) {
        
//        DDLogDebug("Superview: \(view), canvas: \(canvas)")
        
        if view.superview!.isEqual(to: canvas.contentView) {
            view.removeFromSuperview()
            canvas.displayIfNeeded() /// Probs not necessary
        } else {
            fatalError("Idk dude Swift value semantics or sth uchh")
        }
    }
    
    @objc func flush() {
//        canvas.orderOut(nil);
        canvas.contentView = NSView()
    }
    
    
}
