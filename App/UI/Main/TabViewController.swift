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

class TabViewController: NSTabViewController {
    
    // MARK: Vars
    
    private lazy var tabViewSizes: [NSTabViewItem: NSSize] = [:]
    private var windowResizeTimer: Timer?
    private var deactivatedConstraints: [NSLayoutConstraint] = []
    private var injectedConstraints: [NSLayoutConstraint] = []
    private var unselectedTabImageView: NSImageView = NSImageView()
    
    private var initialTabSwitchWasPerformed: Bool = false
    
    // MARK: Constants
    ///     TODO: Think about using validTabs in different places / if using it at all makes sense in the grand architecture
    private let validTabs = ["general", "buttons", "scrolling", "about"]
    
    private var window: ResizingTabWindow? {
        if let w = self.tabView.window as? ResizingTabWindow {
            return w /// This is nil when the app first selects a tab from `viewDidAppear()`. But only when running the app from Xcode debugger!?
        } else {
            return MainAppState.shared.window
        }
    }

    
    // MARK: Hacky tabView manipulation
    
    func _getToolbar(_ w: NSWindow?) -> NSToolbar? {
        
        let window = w ?? MainAppState.shared.window
        
        if let window = window {
            return window.toolbar
        } else {
            return nil
        }
    }
    func _getIndexOfToolBarItem(_ identifier: NSToolbarItem.Identifier, _ toolbar: NSToolbar) -> Int? {
        
        var result: Int? = nil
        for (i, item) in toolbar.items.enumerated() {
            if item.itemIdentifier == identifier {
                result = i
                break;
            }
        }
        return result
    }
    func _getToolbarItem(_ identifier: NSToolbarItem.Identifier, _ toolbar: NSToolbar) -> NSToolbarItem? {
        var result: NSToolbarItem? = nil
        for item in toolbar.items {
            if item.itemIdentifier == identifier {
                result = item
                break;
            }
        }
        return result
    }
    func _getToolbarItemViewer(_ item: NSToolbarItem) -> NSView? {
        let result = SharedUtility.getPrivateValue(of: item, forName: "_itemViewer") as? NSView
        return result
    }
    
    @objc public func coolSelectTab(identifier: String, window w: NSWindow? = nil) {
        
        ///
        /// Summer 2024: macOS 15.0 Beta: Attempt at simpler implementation
        /// (I hope this new method is backwards compatible, but I think so since we're using no more private ivars or methods.)
        
        /// Sometimes you need to pass in window, when you call this right after the window is created.
        
        /// Log
        DDLogDebug("TBS switching to tab \(identifier), windowIsNil: \(w == nil)")
        
        /// Find toolbar item
        guard let toolbar = self._getToolbar(w),
              let item = _getToolbarItem(NSToolbarItem.Identifier(identifier), toolbar) else {
            
            assert(false)
            return
        }
        
        /// Update state on tabView and toolbar
        toolbar.selectedItemIdentifier = NSToolbarItem.Identifier(identifier)
        self.tabView.selectTabViewItem(withIdentifier: identifier)
        
        /// Return
        return;
        
        ///
        /// Old implementation
        ///
        
        /// There's a library method `self.tabView.selectTabViewItem(withIdentifier:)`
        ///     but it doesn't change the selected toolbar button properly, so we have to use horrible hacks.
        /// Sometimes you need to pass in window, when you call this right after the window is created.
        
        let window = w ?? MainAppState.shared.window
        
        guard let window = window, let tb = window.toolbar else { assert(false); return }
        let tbv = SharedUtility.getPrivateValue(of: tb, forName: "_toolbarView")
        
        let lvs: [NSView]?
        
        if #available(macOS 11.0, *) {
            lvs = SharedUtility.getPrivateValue(of: tbv, forName: "_allItemViewers") as? [NSView]
            /// ^ Might be better to use`_layoutViews` vs `_allItemViewers` here
        } else {
            lvs = SharedUtility.getPrivateValue(of: tbv, forName: "_toolbarOrderedItemViewers") as? [NSView]
            /// ^ Might be better to use `_layoutOrderedItemViewers`vs `_toolbarOrderedItemViewers  here
        }
        guard let lvs = lvs else { assert(false); return }
        assert(lvs.count > 0)
        
        var success = false
        outerLoop: for v in lvs {
            guard let item = SharedUtility.getPrivateValue(of: v, forName: "_item") as? NSToolbarItem else { assert(false); return }
            if item.itemIdentifier.rawValue == identifier {
                for sub in v.subviews {
                    if let sub = sub as? NSButton {
                        
                        sub.performClick(nil)
                        
                        success = true
                        break outerLoop
                    }
                }
            }
        }
        assert(success)
    }
    
    @objc public func coolHideTab(identifier: String, window w: NSWindow? = nil) {
        
        ///
        /// Summer 2024: macOS 15.0 Beta: Attempt at simpler implementation
        ///
        
        /// This hides the button for selecting the tab in the UI
        
        /// Log
        DDLogDebug("TBS hiding tab \(identifier), windowIsNil: \(w == nil)")
        
        /// Get toolbar & item
        guard let toolbar = _getToolbar(w),
              let itemIndex = _getIndexOfToolBarItem(NSToolbarItem.Identifier(identifier), toolbar) else {
            
            assert(false)
            return
        }
        
        /// Remove item
        toolbar.removeItem(at: itemIndex)
        
        /// Return
        return
        
        ///
        /// Old implementation
        ///
        
        /// This is copy pasted from `coolSelectTab()`
        /// Hides the tab button from the user, but the tab will still be displayed and we can switch from/to it programmatically
        
        DDLogDebug("TBS hiding tab \(identifier), windowIsNil: \(w == nil)")
        
        let window = w ?? MainAppState.shared.window
        
        guard let window = window,
              let tb = window.toolbar else { assert(false); return }
        let tbv = SharedUtility.getPrivateValue(of: tb, forName: "_toolbarView")
        
        let lvs: NSMutableArray?
        
        if #available(macOS 11.0, *) {
            lvs = SharedUtility.getPrivateValue(of: tbv, forName: "_layoutViews") as? NSMutableArray
        } else {
            /// Note: Removing from `_layoutOrderedItemViewers` doesn't seem to do anything. But I feel like we might still want to remove from both `_toolbarOrderedItemViewers` and `_toolbarOrderedItemViewers` (Edit: what?) so the overall state is for sure valid, cause I don't get what the role of each of the two is.
            lvs = SharedUtility.getPrivateValue(of: tbv, forName: "_toolbarOrderedItemViewers") as? NSMutableArray
        }
        
        guard let lvs = lvs else { assert(false); return }
        assert(lvs.count > 0)
        
        var foundIndex = -1
        var foundLayoutView: NSView? = nil
        for (i, v) in lvs.enumerated() {
            
            guard let item = SharedUtility.getPrivateValue(of: v, forName: "_item") as? NSToolbarItem else { continue /* assert(false); return <<< With the new Sonoma code this crashed. Should be safe to remove. */ }
            guard let v = v as? NSView else { assert(false); return }
            
            if item.itemIdentifier.rawValue == identifier {
                foundIndex = i
                foundLayoutView = v
            }
        }
        assert(foundIndex != -1)
        
        if #available(macOS 14.0, *) {
            /// This would probably also work pre-Sonoma, but no reason to change what works
            tb.removeItem(at: foundIndex)
        } else {
            if let v = foundLayoutView {
                v.isHidden = true
                lvs.remove(v) /// Extremely hacky. Broke in macOS 14.0 Sonoma
            }
        }
        
        /// Layout toolbarView
        /// - Otherwise the removal of the view from the layoutViews will not be reflected and there will be a blank space where the tab was.
        ///     - This occured only sometimes in MMF 3 beta 4 and below, but after making EnabledState slower in Beta 5 and with it making TabViewController.toolbarWillAddItem() slower too, this started to always happen (Ventura Beta)
        guard let tbvv = (tbv as? NSView) else { assert(false); return }
        tbvv.needsLayout = true
        
    }
    
    // MARK: Initialization
    
    var tabsAreConfigured = false
    
    func configureTabs() {
            
        /// Guard multiple invocations
        
        guard !tabsAreConfigured else { assert(false); return }
        tabsAreConfigured = true
        
        ///
        /// Give tabButtons axIdentifiers
        ///
        
        /// Note: Writing this so we can click the button inside the screenshot-taking XCUITest
        
        if let toolbar = _getToolbar(self.window) {
            
            for item in toolbar.items {

                if let itemViewer = _getToolbarItemViewer(item) {
                    itemViewer.setAccessibilityIdentifier(item.itemIdentifier.rawValue)
                } else {
                    assert(false) /// We only need this for screenshot-taking, so we actually don't care if this fails in some edge cases. (Could even turn this whole thing off unless the app is started with the `-MF_ANNOTATE_LOCALIZED_STRINGS` arg)
                }
            }
        } else {
            assert(false)
        }
        
        ///
        /// Hide Pointer tab (because it's unfinished and unused)
        ///
        
        /// Notes:
        /// - (Under Ventura Beta) For some reason, `removeTabViewItem(pointerTab)` (and `tabView.removeTabViewItem()`) crashes here saying the item is not in the tabView. This doesn't make sense since it is found in the array `self.tabViewItems`. So instead we use the hacky coolHideTab() instead.
        /// - Maybe it's better to do this in viewWillAppear?
        
        coolHideTab(identifier: "pointer", window: self.window)
        
        ///
        /// Hide initial tab
        ///

        coolHideTab(identifier: "initial", window: self.window)
        
        ///
        /// Switch tab
        ///
        
        var targetID: String?
        
        if let lastID = config("State.autosave_tabID") as! String? {
            targetID = lastID
        }
        var targetIsValid = targetID != nil && validTabs.contains(targetID!)
        if targetIsValid {
            let isEnabled = EnabledState.shared.isEnabled()
            if !isEnabled && !alwaysEnabledTabs.contains(targetID!) {
                targetIsValid = false
            }
        }
        if !targetIsValid {
            targetID = "general"
        }
        guard let targetID = targetID else { fatalError() }
        
        coolSelectTab(identifier: targetID, window: self.window)
        
        ///
        /// Change to general tab, when app is disabled
        ///
        
        EnabledState.shared.signal.observeValues { isEnabled in
            if !isEnabled {
                guard let currentTab = self.identifierOfSelectedTab() else { return }
                let currentTabWillBeDisabled = !alwaysEnabledTabs.contains(currentTab)
                if currentTabWillBeDisabled {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: { /// Why are we delaying this?
                        self.coolSelectTab(identifier: "general", window: self.window)
                    })
                }
            }
        }
    }
    
    // MARK: Life cycle
    
    override func awakeFromNib() {
        
        super.awakeFromNib()
        /// Debug
        DDLogDebug("TBS tabview awakeFromNib")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        /// Debug
        DDLogDebug("TBS tabview didLoad")
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        /// Debug
        DDLogDebug("TBS tabview willAppear")
        
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        /// Debug
        DDLogDebug("TBS tabview didAppear")
        
        /// Hide tabBar icons pre-Big Sur
        ///  Because the scaling and resolution of the fallback images is terrible and I don't know how to fix. (Haven't spent too much time but I don't see an obvious way)
        
        if #available(macOS 11.0, *) { } else {
            self.window?.toolbar?.displayMode = .labelOnly
        }
        
        /// Configure tabs
        ///     This sometimes doesn't work
        
//        if let tabID = tabViewItem?.identifier as! NSString?, tabID == "initial" {
            configureTabs()
//        }
        
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        
        if let lastID = identifierOfSelectedTab() {
                
            setConfig("State.autosave_tabID", lastID as NSObject)
            commitConfig()
        }
    }
    
    // MARK: Tab selection life cycle
    ///     My understanding of the lifecycle:
    ///     First, appKit calls `tabView(shouldSelect:)`, with the `initial` tabViewItem. We ignore this, because we don't want to display the `initial` tab.
    ///     Then, appKit calls `viewDidAppear()`, which calls `coolSelectTab(identifier:window:)`, which simulates a click on the menubar item for the tab that the user last had open, which then, again, calls `tabView(shouldSelect:)`. This time, we don't ignore, and do return true, and therefore `tabView(willSelect:)` and `tabView(didSelect:)` are called. Normally, we would animate the tab transition, but since we're just starting the app, we turn off animations using the `initialTabSwitchWasPerformed` flag.
    
    override func tabView(_ tabView: NSTabView, shouldSelect tabViewItem: NSTabViewItem?) -> Bool {
        /// shouldSelect
        
        /// This is called twice for some reason! Don't use this to init stuff!!
        
        /// Call super
        guard super.tabView(tabView, shouldSelect: tabViewItem) else { return false }
        
        /// Debug
        DDLogDebug("TBS tabview shouldSelect \(String(describing: tabViewItem?.identifier))")
        
        /// Ignore switch to disabled tabViewItem
        guard let tabID = tabViewItem?.identifier as! NSString?, validTabs.contains(tabID as String) else {
            return false
        }
        
        /// Unwrap window
        guard let window = window else {
            return true /// Why do we return true here?
        }
        /// Disable switching tabs animations
        ///     Layouts break when switching while popover is animating for some reason. Can't remember what happens when switching tabs while tabs are animating
        let popoverIsAnimating = MainAppState.shared.buttonTabController?.restoreDefaultPopoverIsAnimating ?? false
        let tabsAreAnimating = window.tabSwitchIsInProgress
        if tabsAreAnimating || popoverIsAnimating {
            return false
        }
        
        /// Allow select
        return true
    }
    
    override func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        
        /// willSelect
        
        /// Call super
        super.tabView(tabView, willSelect: tabViewItem)
        
        /// Set resizeInProgress
        ///     Maybe it would be better to set this in didSelect?
        window?.tabSwitchIsInProgress = true
        
        /// Debug
        DDLogDebug("TBS tabview willSelect \(String(describing: tabViewItem?.identifier))")
        
        /// Save image of current contentView for fade out animation
        if let originTab = tabView.selectedTabViewItem?.view, let destinationTab = tabViewItem?.view {
            
            /// Get screenshot and store it in imageView
            ///  \discussion Neither `takeImage()` nor `imageWithoutWindowBackground()` work properly. They don't retain the right color of the groupRows of the actionTable and the fillColor of the addField color. I think the addField issue only started appearing after we updated the addField coloring to support desktop tinting. Neither of the two actually seem to capture the background
            
            let imageOfOriginTab = originTab.takeScreenshot()
            let v = NSImageView() /// We have to create a new imageView each time for some reason
            v.imageScaling = .scaleNone
            v.frame = originTab.frame
            v.image = imageOfOriginTab
            unselectedTabImageView = v
            
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
            DDLogDebug("Storing size \(String(describing: originTabViewItem.view?.frame.size)) for tab \(originTabViewItem.identifier!)")
        }
        
        /// Set alpha on fading in view. Necessary for fadeIn animations to work?
        ///     Doesn't work if you set this in didSelect() for some reason.
        tabView.selectedTabViewItem?.view?.subviews[0].alphaValue = 0.0
    }
    
    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        /// didSelect
        
        /// Call super
        super.tabView(tabView, didSelect: tabViewItem)
        
        /// Debug
        DDLogDebug("TBS tabview didSelect \(String(describing: tabViewItem?.identifier))")
        
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
        
        /// Do fade animations
        
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
            /// Zoom out
            ///     This doesn't seem to do anything. Not sure why.
//            unselectedTabImageView.imageScaling = .scaleProportionallyDown
//            unselectedTabImageView.coolSetAnchorPoint(anchorPoint: .init(x: 0.5, y: 0.5))
//            Animate.with(CABasicAnimation(name: .default, duration: fadeDuration)) {
//                unselectedTabImageView.reactiveAnimator().layer.transform.set(CATransform3DMakeScale(0.0, 0.0, 1.0))
//            } onComplete: {
//                self.unselectedTabImageView.layer!.transform = CATransform3DIdentity
//            }
            
        }
        
        /// Set flag
        initialTabSwitchWasPerformed = true
        
    }
    
    // MARK: Window resizing
    
    private func resizeWindowToFit(tabViewItem: NSTabViewItem) -> TimeInterval {
    
        /// Resizes the window so that it fits the content of the tab.
        ///     Resizes such that center x stays the same
        
        /// Get the stored size of the tab we're switching to
        ///     Note: The size of the general tab can change while we're in another tab (if the helper gets disabled), so we're always recalculating its size!
        var size: NSSize? = tabViewSizes[tabViewItem]
        if size == nil || (tabViewItem.identifier as? String) == "general" {
            
            /// Manually calculate the size of the tab
            
            let view = tabViewItem.view
            view?.needsLayout = true
            view?.layoutSubtreeIfNeeded() /// Seems like it's not needed sure if needed
            size = view?.frame.size
        }
        
        /// Setup constraints for resizing
        self.adjustConstraintsForWindowResizing(tabViewItem, size!)
        
        /// Update layout
        tabViewItem.view?.needsLayout = true
        tabViewItem.view?.layoutSubtreeIfNeeded()
        
        /// Guard window and tabSize exist
        
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
        let currentWindowFrame = window.frame
        
        /// Get new window frame
        let targetContentRect = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        let newFrameRect = window.frameRect(forContentRect: targetContentRect)
        
        /// Shift newFrame
        let heightDifference = newFrameRect.size.height - currentWindowFrame.size.height
        let widthDifference = newFrameRect.size.width - currentWindowFrame.size.width
        
        let newOrigin = NSPoint(x: currentWindowFrame.origin.x - round(0.5 * widthDifference), /// Center horizontally
                                y: currentWindowFrame.origin.y - heightDifference) /// Top edge stays in place
        
        var newFrame = NSRect(origin: newOrigin, size: newFrameRect.size)
        
        /// Adjust frameOrigin so that
        ///   the window is fully on screen after resize, if it's fully on screen before resize
        
        if let s = window.screen?.visibleFrame {
            
            let oldFrame = window.frame
            
            /// Left edge
            if newFrame.minX < s.minX /*&& oldFrame.minX >= s.minX*/ { newFrame.origin.x = s.minX }
            /// Right edge
            if newFrame.maxX > s.maxX /*&& oldFrame.maxX <= s.maxX*/ { newFrame.origin.x = s.maxX - newFrame.width }
            /// Bottom edge
            if newFrame.minY < s.minY /*&& oldFrame.minY >= s.minY*/ { newFrame.origin.y = s.minY }
            /// Top edge
//            if newFrame.maxY > s.maxY /*&& oldFrame.maxY <= s.maxY*/ { newFrame.origin.y = s.maxY - newFrame.height }
        }
        
        ///
        /// Animation
        ///
        
        let springSpeed = 3.75
        let springDamping = 1.1 /** 1.1 For more beautiful but slightly floaty animations*/
        var animation: CASpringAnimation? = CASpringAnimation(speed: springSpeed, damping: springDamping)
        
        /// Do special animation when app first starts)
        ///     This doesn't work right when the debugger is attached. Instead the first real, user-initiated tab switch will have this animation. Edit: I think we changed things so it does work with debugger now? Or we prevent animations on initial tab switch during app start some other way. Not sure.
        
        if !initialTabSwitchWasPerformed {
            
            /// Disable animation
            animation = nil
            
            /// Debug
            DDLogDebug("TAB HAD NOOT")
        } else {
            DDLogDebug("TAB HADd")
        }
        
        /// Get durations
        /// Notes:
        /// - fromValue and toValue don't affect duration
        /// - Before spring animations we used to use window.animationResizeTime(newFrame)
        
        let duration = animation?.settlingDuration ?? 0.0
        let fadeDuration = duration * 1.0 /* 0.75 */
        
        /// Debug
        DDLogDebug("Predicted window settling time: \(duration)")
        
        /// Set up resize completion callback
        if windowResizeTimer != nil {
            windowResizeTimer!.invalidate()
            windowResizeTimer = nil
        }
        windowResizeTimer = Timer.scheduledTimer(withTimeInterval: duration+0.1, repeats: false, block: { (timer) in
            /// Note: Adding 0.1 to duration avoids occasional jank. I guess the springAnimation.settlingDuration is sometimes underestimated.
            
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
    
    // MARK: Utility
    
    func tabViewItem(identifier: String) -> NSTabViewItem? {
        
        for item in tabViewItems {
            
            if item.identifier as? String == identifier {
                return item
            }
        }
        
        return nil
    }
    
    @objc public func identifierOfSelectedTab() -> String? {
        return self.tabView.selectedTabViewItem?.identifier as? String
    }
}
