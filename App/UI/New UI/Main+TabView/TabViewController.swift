//
//  TabViewController.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 24.07.21.
//

/// Configuring transition animations and resizing when tabs change
///     Inspiration:  https://gist.github.com/mminer/caec00d2165362ff65e9f1f728cecae2

import Cocoa
import SnapKit
import CocoaLumberjackSwift

class TabViewController: NSTabViewController {
    
    /// Vars
    
    private lazy var tabViewSizes: [NSTabViewItem: NSSize] = [:]
    private var windowResizeTimer: Timer?
    private var deactivatedConstraints: [NSLayoutConstraint] = []
    private var injectedConstraints: [NSLayoutConstraint] = []
    private var unselectedTabImageView: NSImageView = NSImageView()
    
    private var window: ResizingTabWindow? {
        if let w = self.tabView.window as? ResizingTabWindow {
            return w /// This is nil when the app first selects a tab from `viewDidAppear()`. But only when running the app from Xcode debugger!?
        } else {
            return MainAppState.shared.window
        }
    }

    private var initialTabSwitchWasPerformed: Bool = false
    
    /// Other interface
    
    @objc public func coolSelectTab(identifier: String, window w: NSWindow? = nil) {
        
        /// There's a library method `self.tabView.selectTabViewItem(withIdentifier:)`
        ///     but it doesn't change the selected toolbar button properly, so we have to use horrible hacks.
        /// Sometimes you need to pass in window, when you call this right after the window is created.
        
        let window: NSWindow?
        if w == nil {
            window = MainAppState.shared.window
        } else {
            window = w
        }
        
        guard let tb = window?.toolbar else { return }
        let tbv = SharedUtility.getPrivateValue(of: tb, forName: "_toolbarView")
        let lvs = SharedUtility.getPrivateValue(of: tbv, forName: "_allItemViewers") as? [NSView]
        /// ^ Might be better to use`_layoutViews` vs `_allItemViewers` here
        guard let lvs = lvs else { return }
        
        for v in lvs {
            guard let item = SharedUtility.getPrivateValue(of: v, forName: "_item") as? NSToolbarItem else { return }
                    if item.itemIdentifier.rawValue == identifier {
                for sub in v.subviews {
                    if let sub = sub as? NSButton {
                        sub.performClick(nil)
                        return
                    }
                }
            }
        }
    }
    
    @objc public func coolHideTab(identifier: String, window w: NSWindow? = nil) {
        
        /// This is copy pasted from `coolSelectTab()`
        /// Hides the tab button from the user, but the tab will still be displayed and we can switch from/to it programmatically
        
        let window: NSWindow?
        if w == nil {
            window = MainAppState.shared.window
        } else {
            window = w
        }
        
        guard let tb = window?.toolbar else { return }
        let tbv = SharedUtility.getPrivateValue(of: tb, forName: "_toolbarView")
        let lvs = SharedUtility.getPrivateValue(of: tbv, forName: "_layoutViews") as? NSMutableArray
        guard let lvs = lvs else { return }
        
        for v in lvs {
            guard let item = SharedUtility.getPrivateValue(of: v, forName: "_item") as? NSToolbarItem else { return }
            guard let v = v as? NSView else { return }
            
            if item.itemIdentifier.rawValue == identifier {
                v.isHidden = true
                lvs.remove(v) /// Extremely hacky. Might break.
            }
        }
    }
    
    @objc public func identifierOfSelectedTab() -> String? {
        return self.tabView.selectedTabViewItem?.identifier as? String
    }
    
    /// Helper
    
    func createUnselectedTabImageView() -> NSImageView {
        
        let v = NSImageView()
        v.imageScaling = .scaleNone
//        v.frame.origin = NSZeroPoint
//        v.removeConstraints(v.constraints)
//        v.wantsLayer = true /// If we don't set wantsLayer to true, the animations will only work the second time they are done??
        
        return v
    }
    
    /// Life cycle
    ///     My understanding of the lifecycle:
    ///     First, appKit calls `tabView(shouldSelect:)`, with the `initial` tabViewItem. We ignore this, because we don't want to display the `initial` tab.
    ///     Then, appKit calls `viewDidAppear()`, which calls `coolSelectTab(identifier:window:)`, which simulates a click on the menubar item for the tab that the user last had open, which then, again, calls `tabView(shouldSelect:)`. This time, we don't ignore, and do return true, and therefore `tabView(willSelect:)` and `tabView(didSelect:)` are called. Normally, we would animate the tab transition, but since we're just starting the app, we turn off animations using the `initialTabSwitchWasPerformed` flag.
    
    override func viewWillAppear() {
        
    }
    
    override func viewDidAppear() {
        coolHideTab(identifier: "initial", window: self.window)
        
        if let lastID = UserDefaults.standard.value(forKey: "autosave_tabID") as! String?, lastID != "initial" {
//            tabView.selectTabViewItem(withIdentifier: lastID)
            coolSelectTab(identifier: lastID, window: self.window)
        } else {
//            tabView.selectTabViewItem(withIdentifier: "general")
            coolSelectTab(identifier: "general", window: self.window)
        }
    }
    
    override func viewWillDisappear() {
        let lastID = identifierOfSelectedTab()
        UserDefaults.standard.setValue(lastID, forKey: "autosave_tabID")
    }
    
    override func tabView(_ tabView: NSTabView, shouldSelect tabViewItem: NSTabViewItem?) -> Bool {
        /// shouldSelect
        
        /// This is called twice for some reason! Don't use this to init stuff!!
        
        /// Get super result
        let superResult = super.tabView(tabView, shouldSelect: tabViewItem)
        if superResult == false {
            return false
        }
        
        /// Ignore `initial` TabViewItem
        if tabViewItem?.identifier as! NSString == "initial" {
            return false
        }
        
        /// Unwrap window
        guard let window = window else {
            return true /// Why do we return true here?
        }
        /// Check resizeInProgress
        if window.tabSwitchIsInProgress {
            return false
        }
        
        /// Allow select
        return true
    }
    
    override func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        
        /// willSelect
        
        /// Set resizeInProgress
        ///     Maybe it would be better to set this in didSelect?
        window?.tabSwitchIsInProgress = true
        
        /// Call super
        super.tabView(tabView, willSelect: tabViewItem)
        
        /// Save image of current contentView for fade out animation
        if let originTab = tabView.selectedTabViewItem?.view, let destinationTab = tabViewItem?.view {
            
            /// Get screenshot and store it in imageView
            let imageOfOriginTab = originTab.imageWithoutWindowBackground()
            unselectedTabImageView = createUnselectedTabImageView() /// We have to create a new one each time for some reason
            unselectedTabImageView.image = imageOfOriginTab
            unselectedTabImageView.frame = originTab.frame
            
            /// Draw imageView
            ///     Need to draw in willSelect. didSelect doesn't work for some reason
            destinationTab.addSubview(unselectedTabImageView)
            
            /// Add constraints to imageView
            unselectedTabImageView.translatesAutoresizingMaskIntoConstraints = false
            unselectedTabImageView.snp.makeConstraints { make in
                make.centerY.equalTo(destinationTab.snp.centerY)
                make.centerX.equalTo(destinationTab.snp.centerX)
            }
        }
        
        /// Store old tab size
        
        if let originTabViewItem = tabView.selectedTabViewItem {
            self.tabViewSizes[originTabViewItem] = originTabViewItem.view?.frame.size
            DDLogDebug("Storing size \(originTabViewItem.view?.frame.size) for tab \(originTabViewItem.identifier!)")
        }
        
        /// Set alpha on fading in view. Necessary for fadeIn animations to work?
        ///     Doesn't work if you set this in didSelect() for some reason.
        tabView.selectedTabViewItem?.view?.subviews[0].alphaValue = 0.0
    }
    
    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        /// didSelect
        
        /// Call super
        super.tabView(tabView, didSelect: tabViewItem)
        
        /// Guard
        guard let tabViewItem = tabViewItem else { return }
        
        /// Constants
        var fadeInCurve = CAMediaTimingFunction(controlPoints: 0.65, 0, 1, 1) /* strong ease in*/
        var fadeOutCurve = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1) /* default */
        
        /// New curves for new spring animations
        fadeInCurve = CAMediaTimingFunction(controlPoints: 0.25, 0, 1, 1)
        fadeOutCurve = CAMediaTimingFunction(controlPoints: 0.0, 1.0, 0.25, 1)
        
        /// Resize window and stuff
        ///     Doing this here in didSelect instead of in willSelect makes the animation smoother for some reason
        var resizeDuration = self.resizeWindowToFit(tabViewItem: tabViewItem)
        resizeDuration *= 0.9 /// Because spring animations take long to settle
        let fadeDuration = resizeDuration /* max(0.135, resizeDuration) */
        
        if let fadeInView = tabViewItem.view?.subviews[0] {
            
            unselectedTabImageView.wantsLayer = true
            fadeInView.wantsLayer = true /// If we don't set wantsLayer true, then the animation will only start working after the first time?
            unselectedTabImageView.alphaValue = 1.0
            fadeInView.alphaValue = 0 /// This doesn't work, need to do it in willSelect for some reason...
            
            /// Fade in
            Animate.with(CABasicAnimation(curve: fadeInCurve, duration: fadeDuration)) {
                fadeInView.reactiveAnimator().alphaValue.set(1)
            }
            /// Fade out
            Animate.with(CABasicAnimation(curve: fadeOutCurve, duration: fadeDuration)) {
                unselectedTabImageView.reactiveAnimator().alphaValue.set(0)
            } onComplete: {
                /// If we don't remove this ModCaptureTextFields that are under the invisible image view won't react to clicks. Not sure why.
                self.unselectedTabImageView.removeFromSuperview()
            }
            
        }
        
        /// Set flag
        initialTabSwitchWasPerformed = true
        
    }
    
    /// Resizes the window so that it fits the content of the tab.
    ///     Resizes such that center x stays the same
    private func resizeWindowToFit(tabViewItem: NSTabViewItem) -> TimeInterval {
        
        var size: NSSize? = tabViewSizes[tabViewItem]
        if size == nil {
            let view = tabViewItem.view
            view?.needsLayout = true
            view?.layoutSubtreeIfNeeded() /// Seems like it's not needed sure if needed
            size = view?.frame.size
        }
        
        self.adjustConstraintsForWindowResizing(tabViewItem, size!)
        
        tabViewItem.view?.needsLayout = true
        tabViewItem.view?.layoutSubtreeIfNeeded()
        
        /* let tabView = self.tabView */ /// This is sometimes nil when switching to general tab. Weird.
        let window = self.window /* tabView.window */
        guard let size = size,
              let window = window else {
            /// Always restore valid state, even in edge cases
            restoreConstraintsAfterWindowResizing()
            self.window?.tabSwitchIsInProgress = false
            return 0
        }

        /// Get current window frame
        var currentWindowFrame = window.frame
        
        /// Get new window frame
        let targetContentRect = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        var newFrameRect = window.frameRect(forContentRect: targetContentRect)
        
        /// Shift newFrame
        let heightDifference = newFrameRect.size.height - currentWindowFrame.size.height
        let widthDifference = newFrameRect.size.width - currentWindowFrame.size.width
        
        let newOrigin = NSPoint(x: currentWindowFrame.origin.x - round(0.5 * widthDifference), /// Center horizontally
                                y: currentWindowFrame.origin.y - heightDifference) /// Top edge stays in place
        
        var newFrame = NSRect(origin: newOrigin, size: newFrameRect.size)
        
        /// Adjust frameOrigin so that
        ///   the window is fully on screen after resize, if it's fully on screen before resize
        
        if let s = window.screen?.frame {
            
            let oldFrame = window.frame
            
            /// Left edge
            if newFrame.minX < s.minX && oldFrame.minX >= s.minX { newFrame.origin.x = s.minX }
            /// Right edge
            if newFrame.maxX > s.maxX && oldFrame.maxX <= s.maxX { newFrame.origin.x = s.maxX - newFrame.width }
            /// Bottom edge
            if newFrame.minY < s.minY /*&& oldFrame.minY >= s.minY*/ { newFrame.origin.y = s.minY }
            /// Top edge
//            if newFrame.maxY > s.maxY && oldFrame.maxY <= s.maxY { newFrame.origin.y = s.maxY - newFrame.height }
        }
        
        ///
        /// Animation
        ///
        
        let springSpeed = 3.75
        let springDamping = 1.1 /** 1.1 For more beautiful but slightly floaty animations*/
        var animation: CASpringAnimation? = CASpringAnimation(speed: springSpeed, damping: springDamping)
        
        /// Do special animation when app first starts)
        ///     This doesn't work right when the debugger is attached. Instead the first real, user-initiated tab switch will have this animation
        
        if !initialTabSwitchWasPerformed {
            
            /// Disable animation
            animation = nil
            
            /// Debug
            DDLogDebug("TAB HAD NOOT")
        } else {
            DDLogDebug("TAB HADd")
        }
        
        /// Get durations
        /// Note: fromValue and toValue don't affect duration
        ///     Before spring animations we used to use window.animationResizeTime(newFrame)
        
        let duration = animation?.settlingDuration ?? 0.0
        var fadeDuration = duration * 1.0 /* 0.75 */
        
        /// Debug
        DDLogDebug("Predicted window settling time: \(duration)")
        
        /// Set up resize completion callback
        if windowResizeTimer != nil {
            windowResizeTimer!.invalidate()
            windowResizeTimer = nil
        }
        windowResizeTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false, block: { (timer) in
            
            /// After the resize animation, we can add the constraints back in
            self.restoreConstraintsAfterWindowResizing()
            /// Set resizeInProgress
            self.window!.tabSwitchIsInProgress = false
        })
        
        /// Play resize animation
        ///     NSAnimationManager doesn't work anymore for animating windowFrame under Ventura Beta, so we have to use this manual method
        window.setFrame(newFrame, withSpringAnimation: animation)
        
        return fadeDuration
    }
    
    /// Helper functions

    fileprivate func restoreConstraintsAfterWindowResizing() {
        
        /// Add removed constraints back in
        
        for c in deactivatedConstraints {
            c.isActive = true
        }
        
        /// Remove added constraints
        for c in injectedConstraints {
            c.isActive = false
        }
    }
    
    fileprivate func adjustConstraintsForWindowResizing(_ tabViewItem: NSTabViewItem, _ targetSize: NSSize) {
        
        /// Temporarily change constraints so that the window resizing animation will work smoothly
        ///     Constraints can force a certain window size which will interfere with the window resizing animation we want to generate in resizeWindowToFit()
        
        ///
        /// Insert new constraints
        ///
        
        injectedConstraints = []
        
        /// Add in size constraints
        ///     So it doesn't do weird stuff
        ///     This is a little messy. And not sure if should be done here.
        
        let contentView = tabViewItem.view!
        let contentWidth = contentView.widthAnchor.constraint(equalToConstant: targetSize.width)
        let contentHeigth = contentView.heightAnchor.constraint(equalToConstant: targetSize.height)
        contentWidth.isActive = true
        contentHeigth.isActive = true
        contentView.needsLayout = true
        contentView.layoutSubtreeIfNeeded()
        
        let wrapperView = contentView.subviews[0]
        let wrapWidth = wrapperView.widthAnchor.constraint(equalToConstant: wrapperView.frame.width)
        let wrapHeight = wrapperView.heightAnchor.constraint(equalToConstant: wrapperView.frame.height)
        
        contentWidth.isActive = false
        contentHeigth.isActive = false
        wrapWidth.isActive = true
        wrapHeight.isActive = true
        
        injectedConstraints.append(contentsOf: [wrapWidth, wrapHeight])
        
        /// Add in centering constraints
        ///     For nice animation
        
        let centerXOffset = wrapperView.frame.midX - contentView.bounds.midX
        let centerYOffset = wrapperView.frame.midY - contentView.bounds.midY
        let centerX = wrapperView.centerXAnchor.constraint(equalTo: wrapperView.superview!.centerXAnchor, constant: -centerXOffset)
        let centerY = wrapperView.centerYAnchor.constraint(equalTo: wrapperView.superview!.centerYAnchor, constant: -centerYOffset)
        centerX.isActive = true
        centerY.isActive = true
        
        /// Store injected constraints
        injectedConstraints.append(contentsOf: [centerX, centerY])
        
        ///
        /// Deactivate constraints
        ///
        
        deactivatedConstraints = []
        for constraint in tabViewItem.view!.constraints {
            
            if self.isConstraintToRemove(constraint, target: tabViewItem) {
                constraint.isActive = false
                deactivatedConstraints.append(constraint)
            }
        }
    }
    
    fileprivate func isConstraintToRemove(_ constraint: NSLayoutConstraint, target targetTabViewItem: NSTabViewItem) -> Bool {
        /// Helper for adjustConstraintsForWindowResizing
        
        let target = targetTabViewItem.view
        
        
        let targetIsFirstItem: Bool = constraint.firstItem as? NSView == target
        
        if !targetIsFirstItem {
//            assert(constraint.secondItem as? NSView == target)
        }
        
        let attributeOnTarget: NSLayoutConstraint.Attribute
        
        if targetIsFirstItem {
            attributeOnTarget = constraint.firstAttribute
        } else {
            attributeOnTarget = constraint.secondAttribute
        }
        
        switch attributeOnTarget {
        case .leading, .trailing, .bottom, .top: /// Aren't there other constraints we should remove?
            return true
        default:
            return false
        }
    }
}
