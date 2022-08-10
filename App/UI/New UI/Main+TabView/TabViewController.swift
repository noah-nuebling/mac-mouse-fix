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
    
    private var window: ResizingTabWindow? { self.view.window as? ResizingTabWindow }

    /// Other interface
    
    @objc public func coolSelectTab(identifier: String) {
        
        /// There's a library method `self.tabView.selectTabViewItem(withIdentifier:)`
        ///     but it doesn't change the selected toolbar button properly, so we have to use horrible hacks.
        
        guard let tb = MainAppState.shared.window?.toolbar else { return }
        let tbv = SharedUtility.getPrivateValue(of: tb, forName: "_toolbarView")
        let lvs = SharedUtility.getPrivateValue(of: tbv, forName: "_layoutViews") as? [NSView]
        guard let lvs = lvs else { return }
        
        for v in lvs {
            guard let item = SharedUtility.getPrivateValue(of: v, forName: "_item") as? NSToolbarItem else { return }
                    if item.itemIdentifier.rawValue == identifier {
                for sub in v.subviews {
                    if let sub = sub as? NSButton {
                        sub.performClick(nil)
                    }
                }
            }
        }
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
    
    override func tabView(_ tabView: NSTabView, shouldSelect tabViewItem: NSTabViewItem?) -> Bool {
        /// shouldSelect
        
        /// This is called twice for some reason! Don't use this to init stuff!!
        
        /// Get super result
        let superResult = super.tabView(tabView, shouldSelect: tabViewItem)
        if superResult == false {
            return false
        }
        
        /// Unwrap window
        guard let window = window else {
            return true
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
        let fadeDuration = max(0.135, resizeDuration)
        
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
    }
    
    /// Resizes the window so that it fits the content of the tab.
    ///     Resizes such that center x stays the same
    private func resizeWindowToFit(tabViewItem: NSTabViewItem) -> TimeInterval {
        
        self.adjustConstraintsForWindowResizing(tabViewItem)
        
        var size: NSSize? = tabViewSizes[tabViewItem]
        if size == nil {
            size = tabViewItem.view?.frame.size
        }
        
        guard let size = size, let window = view.window as? ResizingTabWindow else {
            /// Always restore valid state, even in edge cases
            restoreConstraintsAfterWindowResizing()
            self.window?.tabSwitchIsInProgress = false
            return 0
        }

        /// Get new window frame
        let targetContentRect = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        let targetWindowFrame = window.frameRect(forContentRect: targetContentRect)
        let currentWindowFrame = window.frame
        
        let heightDifference = targetWindowFrame.size.height - currentWindowFrame.size.height
        let widthDifference = targetWindowFrame.size.width - currentWindowFrame.size.width
        
        let newOrigin = NSPoint(x: currentWindowFrame.origin.x - round(0.5 * widthDifference), /// Center horizontally
                                y: currentWindowFrame.origin.y - heightDifference) /// Top edge stays in place
        
        var newFrame = NSRect(origin: newOrigin, size: targetWindowFrame.size)
        
        /// Adjust frameOrigin so that
        ///   the window is fully on screen after resize, if it's fully on screen before resize
        
        if let s = window.screen?.frame {
            
            let oldFrame = window.frame
            
            /// Left edge
            if newFrame.minX < s.minX && oldFrame.minX >= s.minX { newFrame.origin.x = s.minX }
            /// Right edge
            if newFrame.maxX > s.maxX && oldFrame.maxX <= s.maxX { newFrame.origin.x = s.maxX - newFrame.width }
            /// Bottom edge
//                if newFrame.minY < s.minY && oldFrame.minY >= s.minY { newFrame.origin.y = s.minY }
            /// Top edge
//                if newFrame.maxY > s.maxY && oldFrame.maxY <= s.maxY { newFrame.origin.y = s.maxY - newFrame.height }
        }
        
        ///
        /// Animation
        ///
        
        let springSpeed = 3.75
        let springDamping = 1.1 /* 1.1 For more beautiful but slightly floaty animations*/
        let animation = CASpringAnimation(speed: springSpeed, damping: springDamping)
        
        /// Get durations
        /// Note: fromValue and toValue don't affect duration
        ///     Before spring animations we used to use window.animationResizeTime(newFrame)
        let duration = animation.settlingDuration
        
        let fadeDuration = duration * 1.0 /* 0.75 */
        
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
    
    fileprivate func adjustConstraintsForWindowResizing(_ tabViewItem: NSTabViewItem) {
        
        /// Temporarily change constraints so that the window resizing animation will work smoothly
        ///     Constraints can force a certain window size which will interfere with the window resizing animation we want to generate in resizeWindowToFit()
        
        /// Deactivate edge constraints
        
        deactivatedConstraints = []
        for constraint in tabViewItem.view!.constraints {
            
            if self.isConstraintToRemove(constraint, target: tabViewItem) {
                constraint.isActive = false
                deactivatedConstraints.append(constraint)
            }
        }
        
        /// Add in centering constraints
        ///     For nice animation
        
        let wrapperView = tabViewItem.view!.subviews[0]
        let centerX = wrapperView.centerXAnchor.constraint(equalTo: wrapperView.superview!.centerXAnchor)
        let centerY = wrapperView.centerYAnchor.constraint(equalTo: wrapperView.superview!.centerYAnchor)
        centerX.isActive = true
        centerY.isActive = true
        
        injectedConstraints = [centerX, centerY]
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
