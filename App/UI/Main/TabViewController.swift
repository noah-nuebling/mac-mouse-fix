//
//  TabViewController.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 24.07.21.
//

/// Configuring transition animations and resizing when tabs change
///     Inspiration:  https://gist.github.com/mminer/caec00d2165362ff65e9f1f728cecae2

/// [Aug 2025]
///     We were trying to achieve the __NSWindowToolbarStylePreference__ layout
///         - This layout is seen in settings all across macOS, e.g. Safari, Finder, etc.)
///         - Method 1: In macOS 10.10, Apple introduced a way to achieve this using is using Storyboards, NSTabViewController, and 'child NSViewControllers' for each of the tabs.
///             - This is what we're implementing here as of MMF 3.0.7
///             - See this SO post for more: https://stackoverflow.com/a/41155700/10601702
///         - Method 2: Simply use vanilla NSWindow, NSToolbar, NSToolbarItem, and NSTabView directly (without any controllers or storyboards managing them) and just configure them in a specific way to achieve the same result.
///             - You have to write a tiny bit of glue code to keep the selected tab in-sync with the selected NSToolbarItem – But it's just just a tiny bit!
///             - Pro: This seems wayy simpler than the NSTabViewController stuff! Especially since a large part of the implementation here seems to be hacking into that NSTabViewController abstraction since it doesn't do what we want (See `coolHideTab()`, `coolSelectTab()`)
///             - Pro: This would also allow us to move away from the Storyboard – which feels unwieldly and which prevents us from incrementally replacing some of the views with pure objc code (instead of IB) – which would be easier to maintain and adapt to different macOS versions (See swiftui-test-tahoe-beta project)
///                 - Update: [Sep 2025] You can actually easily define the views in code while still using a Storyboard for Navigation. See `swiftui-test-tahoe-beta`
///             - Reference: You can see an example of `Method 2`this in the project `repro-tahoe-toolbar-button-hover-inconsistency` which I've uploaded to GitHub.
///             - Strategy Discussion:
///                 - When we update the MMF 3 UI:
///                     - Maybe we should move to using a sidebar instead of a tab-bar (as is seen in System Settings and Xcode settings under macOS Tahoe). That seems more popular now. (Although I find tab bar nicer I think, especially since we only have a few tabs and like to resize the window with our nice animations. – but being close to the stock apps is also worth a lot imo)
///                     - Maybe we should move to using Catalyst to make an iPad port easier later
///                         - I heard Catalyst apps feel very similar to AppKit now under Tahoe – not 'out of place' anymore – I think I can feel that, too?
///                             - Also with iPad getting a more 'desktop-like' experience, I feel like UIKit might get even better on macOS in the future, and there may not be a reason to use AppKit anymore.
///                         - I don't wanna use SwiftUI since I feel like SwiftUI apps feel very slow and janky on macOS, plus I don't like Swift, plus  I heard SwiftUI is fiddly if you want customized behavior (which we often want). Also AppKit/UIKit is barely less expressive when you define a few little macros for the boilerplate (See swiftui-test-tahoe-beta project)
///                         - Update: [Sep 2025] Changed my opinions on this. See `swiftui-test-tahoe-beta`.

import Cocoa
import CocoaLumberjackSwift
import UniformTypeIdentifiers

class TabViewController: NSTabViewController {
    
    // MARK: Vars
    
    private lazy var tabViewSizes: [NSTabViewItem: NSSize] = [:]
    private var windowResizeTimer: Timer?
    private var deactivatedConstraints: [NSLayoutConstraint] = []
    private var injectedConstraints: [NSLayoutConstraint] = []
    private var unselectedTabImageView: NSImageView = NSImageView()
    
    private var initialTabSwitchWasPerformed: Bool = false
    
    var buttonsVCEmbedConstraints: [NSLayoutConstraint] = []
    var scrollingVCEmbedConstraints: [NSLayoutConstraint] = []
    
    private var tabSwitchGeneration: Int = 0
    private var pendingSelectedTabItem: NSTabViewItem?
    
    private weak var currentContentView: NSView?
    private var currentContentConstraints: [NSLayoutConstraint] = []
    
    // MARK: Constants
    ///     TODO: Think about using validTabs in different places / if using it at all makes sense in the grand architecture
    private let validTabs = ["general", "buttons", "scrolling", "pointer", "apps", "about"]
    
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
                    // No itemViewer for this item (e.g. flexibleSpace), skip safely
                }
            }
        } else {
            assert(false)
        }
        
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
        self.appSelectorBar?.selectApp(bundleID: Config.uiAppOverrideBundleID())
    }
    
    // MARK: Life cycle
    
    var appSelectorBar: AppSelectorBar? {
        return appOverrideViewController?.appSelectorBar
    }
    
    override func awakeFromNib() {
        
        super.awakeFromNib()
        /// Debug
        DDLogDebug("TBS tabview awakeFromNib")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DDLogDebug("TBS tabview didLoad")
        
        DDLogDebug("TBS DEBUG: BEFORE FOREACH")
        // Force-load child tab views so they are instantiated and accessible
        self.tabViewItems.forEach { item in
            _ = item.viewController?.view
        }
        DDLogDebug("TBS DEBUG: AFTER FOREACH")
        
        // Dynamically insert the "apps" tab item
        let appTabItem = NSTabViewItem(identifier: "apps")
        appTabItem.label = "应用"
        if #available(macOS 11.0, *) {
            appTabItem.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: nil)
        } else {
            appTabItem.image = NSImage(named: "NSFolder")
        }
        
        let appVC = AppOverrideViewController()
        appVC.mainTabVC = self
        appTabItem.viewController = appVC
        
        DDLogDebug("TBS DEBUG: before insertTabViewItem")
        // Insert right before the "about" tab (the last item)
        self.insertTabViewItem(appTabItem, at: self.tabViewItems.count - 1)
        DDLogDebug("TBS DEBUG: after insertTabViewItem")
        
        // Setup a fallback trigger to ensure configureTabs is called
        // even if AppKit bypasses viewWillAppear during initial window presentation.
        DDLogDebug("TBS DEBUG: viewDidLoad scheduling main async block now")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                DDLogDebug("TBS DEBUG: self is nil inside async block!")
                return
            }
            DDLogDebug("TBS DEBUG: self.tabsAreConfigured = \(self.tabsAreConfigured)")
            if !self.tabsAreConfigured {
                if let win = self.window {
                    let toolbar = self._getToolbar(win)
                    DDLogDebug("TBS DEBUG: window is \(win), toolbar is \(String(describing: toolbar))")
                    if toolbar != nil {
                        DDLogDebug("TBS DEBUG: calling configureTabs now")
                        self.configureTabs()
                    } else {
                        DDLogDebug("TBS DEBUG: toolbar is nil, skipping")
                    }
                } else {
                    DDLogDebug("TBS DEBUG: window is nil, skipping")
                }
            }
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        /// Debug
        DDLogDebug("TBS tabview willAppear")
        
        /// Initialize things
        ///     [Sep 2025] Moved from viewDidAppear() to viewWillAppear() in MMF 3.0.8 to prevent occasional flashing of the window at the wrong size.
        do {
            /// Hide tabBar icons pre-Big Sur
            ///  Because the scaling and resolution of the fallback images is terrible and I don't know how to fix. (Haven't spent too much time but I don't see an obvious way)
            if #available(macOS 11.0, *) { } else {
                self.window?.toolbar?.displayMode = .labelOnly
            }
            
            /// Configure tabs
            if !tabsAreConfigured {
                configureTabs()
            }
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        /// Debug
        DDLogDebug("TBS tabview didAppear")
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
    
    var buttonsVC: NSViewController? {
        return self.tabViewItems.first { $0.identifier as? String == "buttons" }?.viewController
    }
    var scrollingVC: NSViewController? {
        return self.tabViewItems.first { $0.identifier as? String == "scrolling" }?.viewController
    }
    var appOverrideViewController: AppOverrideViewController? {
        return self.tabViewItems.first { $0.identifier as? String == "apps" }?.viewController as? AppOverrideViewController
    }

    override func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        
        /// willSelect
        
        /// Call super
        super.tabView(tabView, willSelect: tabViewItem)
        
        // Guard: increment generation to cancel any in-flight async installs
        tabSwitchGeneration += 1
        pendingSelectedTabItem = tabViewItem
        
        /// Set resizeInProgress
        window?.tabSwitchIsInProgress = true
        
        /// Debug
        DDLogDebug("TBS tabview willSelect \(String(describing: tabViewItem?.identifier))")
        let originIdentifier = tabView.selectedTabViewItem?.identifier as? String
        let destinationIdentifier = tabViewItem?.identifier as? String
        let isAppsTransition = originIdentifier == "apps" || destinationIdentifier == "apps"
        if destinationIdentifier == "apps" {
            self.appOverrideViewController?.appSelectorBar?.reloadData()
        }
        
        /// Store old tab size (read-only, safe in willSelect)
        if let originTabViewItem = tabView.selectedTabViewItem {
            self.tabViewSizes[originTabViewItem] = originTabViewItem.view?.frame.size
            DDLogDebug("TBS Storing size \(String(describing: originTabViewItem.view?.frame.size)) for tab \(originTabViewItem.identifier!)")
        }
        
        // Capture screenshot of the current tab for crossfade animation.
        // Store it but do NOT call addSubview here — doing so inside AppKit's
        // selectTabViewItem: call stack triggers NSViewGetEffectiveVibrantBlendingStyle
        // recursion and crashes with stack overflow.
        if let originTab = tabView.selectedTabViewItem?.view {
            let imageOfOriginTab = originTab.takeScreenshot()
            let v = NSImageView()
            v.imageScaling = .scaleNone
            v.frame = originTab.frame
            v.image = imageOfOriginTab
            unselectedTabImageView = v
        }
        
        /// Set alpha on fading in view. Necessary for fadeIn animations to work?
        ///     Doesn't work if you set this in didSelect() for some reason.
        if initialTabSwitchWasPerformed {
            tabViewItem?.view?.subviews.first?.alphaValue = 0.0
        }
    }
    
    private func installContentViewForSelectedTab(_ tabViewItem: NSTabViewItem) {
        let identifier = tabViewItem.identifier as? String
        
        
        // For buttons/scrolling tabs: NSTabViewController already owns their content
        // via tabViewItem.viewController. Do NOT manually re-add those VCs' views into
        // tabViewItem.view — that creates a superview cycle and triggers 261k-level
        // NSViewGetEffectiveVibrantBlendingStyle recursion.
        //
        // Only the "apps" tab needs custom embedding: we put buttonsVC.view or scrollingVC.view
        // into AppOverrideViewController.containerView (a private container we own).
        
        if identifier == "apps" {
            // Entering Apps Tab: embed sub-view into AppOverrideViewController.containerView
            self.appOverrideViewController?.appSelectorBar?.reloadData()
            self.appOverrideViewController?.embedViewForCurrentSegment()
            
            // Activate per-app config
            if let selectedBid = self.appOverrideViewController?.appSelectorBar?.selectedBundleID {
                Config.setUIAppOverrideBundleID(selectedBid)
            } else {
                Config.setUIAppOverrideBundleID(nil)
            }
            ReactiveConfig.shared.react(newConfig: Config.shared.config)
        } else {
            // Leaving Apps Tab (or switching between other tabs):
            // Return buttonsVC/scrollingVC views to AppOverrideViewController.containerView cleanup
            // is handled by embedViewForCurrentSegment on next entry.
            // Here we only need to reset global config.
            Config.setUIAppOverrideBundleID(nil)
            ReactiveConfig.shared.react(newConfig: Config.shared.config)
        }
    }
    
    fileprivate func validateContentInstall(_ newView: NSView, into container: NSView, tabViewItem: NSTabViewItem) -> Bool {
        if newView === container {
            logInvalidInstall("newView === container", newView: newView, container: container, tabViewItem: tabViewItem)
            return false
        }
        
        if newView === self.view {
            logInvalidInstall("newView === self.view", newView: newView, container: container, tabViewItem: tabViewItem)
            return false
        }
        
        if hasSuperviewCycle(startingAt: container) || hasSuperviewCycle(startingAt: newView) {
            logInvalidInstall("existing superview cycle detected", newView: newView, container: container, tabViewItem: tabViewItem)
            return false
        }
        
        if isAncestor(newView, of: container) {
            logInvalidInstall("newView is an ancestor of container", newView: newView, container: container, tabViewItem: tabViewItem)
            return false
        }
        
        if newView.isDescendant(of: container), newView.superview !== container {
            logInvalidInstall("newView is already nested inside container, but not as direct content", newView: newView, container: container, tabViewItem: tabViewItem)
            return false
        }
        
        return true
    }
    
    private func isAncestor(_ possibleAncestor: NSView, of view: NSView) -> Bool {
        var cursor = view.superview
        var seen = Set<ObjectIdentifier>()
        
        while let current = cursor {
            let id = ObjectIdentifier(current)
            if seen.contains(id) {
                return true
            }
            seen.insert(id)
            
            if current === possibleAncestor {
                return true
            }
            
            cursor = current.superview
        }
        
        return false
    }
    
    private func hasSuperviewCycle(startingAt view: NSView) -> Bool {
        var cursor: NSView? = view
        var seen = Set<ObjectIdentifier>()
        
        while let current = cursor {
            let id = ObjectIdentifier(current)
            if seen.contains(id) {
                return true
            }
            seen.insert(id)
            cursor = current.superview
        }
        
        return false
    }
    
    private func describeView(_ view: NSView) -> String {
        let pointer = Unmanaged.passUnretained(view).toOpaque()
        return "\(type(of: view))@\(pointer)"
    }
    
    private func superviewChainDescription(_ view: NSView, limit: Int = 40) -> String {
        var result: [String] = []
        var cursor: NSView? = view
        var seen = Set<ObjectIdentifier>()
        
        while let current = cursor, result.count < limit {
            let id = ObjectIdentifier(current)
            result.append(describeView(current))
            
            if seen.contains(id) {
                result.append("<cycle>")
                break
            }
            
            seen.insert(id)
            cursor = current.superview
        }
        
        if result.count >= limit {
            result.append("<truncated>")
        }
        
        return result.joined(separator: " -> ")
    }
    
    private func logInvalidInstall(_ reason: String, newView: NSView, container: NSView, tabViewItem: NSTabViewItem) {
        NSLog("""
        Invalid tab content install: \(reason)
        tabViewItem: \(String(describing: tabViewItem.identifier))
        newView: \(describeView(newView))
        container: \(describeView(container))
        newView.superviewChain: \(superviewChainDescription(newView))
        container.superviewChain: \(superviewChainDescription(container))
        """)
    }
    
    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        /// didSelect
        
        /// Call super
        super.tabView(tabView, didSelect: tabViewItem)
        
        /// Debug
        DDLogDebug("TBS tabview didSelect \(String(describing: tabViewItem?.identifier))")
        
        /// Guard
        guard let tabViewItem = tabViewItem else { return }
        
        tabSwitchGeneration += 1
        
        // Install content view synchronously so we are already populated when measuring size.
        self.installContentViewForSelectedTab(tabViewItem)
        
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
        let fadeDuration = resizeDuration
        
        // Now it is safe to addSubview — we are in didSelect, not willSelect.
        // AppKit's internal tab selection machinery has completed.
        if let destinationTab = tabViewItem.view, unselectedTabImageView.image != nil {
            unselectedTabImageView.frame = destinationTab.frame
            destinationTab.addSubview(unselectedTabImageView)
            unselectedTabImageView.translatesAutoresizingMaskIntoConstraints = false
            unselectedTabImageView.centerYAnchor.constraint(equalTo: destinationTab.centerYAnchor).isActive = true
            unselectedTabImageView.centerXAnchor.constraint(equalTo: destinationTab.centerXAnchor).isActive = true
        }
        
        if !initialTabSwitchWasPerformed {
            if let firstSub = tabViewItem.view?.subviews.first {
                firstSub.wantsLayer = true
                firstSub.alphaValue = 1.0
                firstSub.needsDisplay = true
            }
            unselectedTabImageView.removeFromSuperview()
            unselectedTabImageView.image = nil
        } else if let fadeInView = tabViewItem.view?.subviews.first {
            
            unselectedTabImageView.wantsLayer = true
            fadeInView.wantsLayer = true
            unselectedTabImageView.alphaValue = 1.0
            fadeInView.alphaValue = 0
            
            /// Fade in
            Animate.with(CABasicAnimation(curve: fadeInCurve, duration: fadeDuration)) {
                fadeInView.reactiveAnimator().alphaValue.set(1)
            }
            /// Fade out
            Animate.with(CABasicAnimation(curve: fadeOutCurve, duration: fadeDuration)) {
                unselectedTabImageView.reactiveAnimator().alphaValue.set(0)
            } onComplete: {
                self.unselectedTabImageView.removeFromSuperview()
                self.unselectedTabImageView.image = nil
            }
        } else {
            unselectedTabImageView.removeFromSuperview()
            unselectedTabImageView.image = nil
        }
        
        /// Set flag
        initialTabSwitchWasPerformed = true
    }
    
    // MARK: Window resizing
    
    @objc public func resizeWindowToFit(tabViewItem: NSTabViewItem) -> TimeInterval {
    
        /// Resizes the window so that it fits the content of the tab.
        ///     Resizes such that center x stays the same
        
        /// Get the stored size of the tab we're switching to
        ///     Note: The size of the general tab can change while we're in another tab (if the helper gets disabled), so we're always recalculating its size!
        var size: NSSize? = tabViewSizes[tabViewItem]
        if size == nil || (tabViewItem.identifier as? String) == "general" || (tabViewItem.identifier as? String) == "apps" {
            
            /// Calculate the natural content size of the tab
            ///     Previous approach (now removed): Temporarily set window to 99999x99999 and read frame.size.
            ///         Problem: NSTabView pins tabViewItem.view to its content area via Auto Layout constraints.
            ///         When the window is 99999, the content area is 99999, and tabViewItem.view.frame.size
            ///         returns ~99999 — causing the window to resize to near-infinite dimensions.
            ///     Current approach: Use fittingSize which returns the minimum size that satisfies
            ///         all required-level constraints, independent of the current container size.
            ///         This works because tab widths are hardcoded via applyHardcodedTabWidth() and
            ///         AppOverrideViewController.hardcodedWidth. [May 2026]
            ///     Original comment about 99999: "This should no longer be necessary, since we're now
            ///         preventing the ambiguity by either turning off wrapping or hardcoding an exact
            ///         width for the window in applyHardcodedTabWidth()" [Sep 2025]
            
            tabViewItem.view?.needsLayout = true
            tabViewItem.view?.layoutSubtreeIfNeeded()
            size = tabViewItem.view?.fittingSize
        }
        
        if let fittingSize = size, fittingSize.width < 1 || fittingSize.height < 1 {
            DDLogWarn("Ignoring invalid tab fittingSize \(fittingSize) for \(String(describing: tabViewItem.identifier)).")
            if let cachedSize = tabViewSizes[tabViewItem], cachedSize.width >= 1, cachedSize.height >= 1 {
                size = cachedSize
            } else {
                return 0
            }
        }
        
        if let validSize = size, validSize.width >= 1, validSize.height >= 1 {
            tabViewSizes[tabViewItem] = validSize
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
            ///            if newFrame.maxY > s.maxY /*&& oldFrame.maxY <= s.maxY*/ { newFrame.origin.y = s.maxY - newFrame.height }
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
        
        /// Guard: no subviews
        guard !contentView.subviews.isEmpty else {
            deactivatedConstraints = []
            return
        }
        
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
        let injectedSet = Set(injectedConstraints.map { ObjectIdentifier($0) })
        for constraint in tabViewItem.view!.constraints {
            /// Skip constraints we just injected — they must stay active during the resize animation
            if injectedSet.contains(ObjectIdentifier(constraint)) { continue }
            
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
        case .leading, .trailing, .bottom, .top /// Aren't there other constraints we should remove?
                 , .width                        /// Added .width to support `applyHardcodedTabWidth` [Sep 2025]
        :
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
    
    // MARK: - App Specific Config Override UI Bridge
    
    func appSelectorChangedExternal() {
        DDLogInfo("[TabViewController] appSelectorChangedExternal called. Refreshing embed view.")
        if let selectedItem = self.tabView.selectedTabViewItem, (selectedItem.identifier as? String) == "apps" {
            self.appOverrideViewController?.embedViewForCurrentSegment()
            _ = self.resizeWindowToFit(tabViewItem: selectedItem)
        }
    }
    
    func addApplicationActionExternal() {
        addApplicationAction()
    }
    
    @objc func addApplicationOverride(bundleID: String) {
        DDLogInfo("[AppSelectorBar] addApplicationOverride called for: \(bundleID)")
        let appOverridesKey = "AppOverrides"
        let appOverrides = Config.shared.config.object(forKey: appOverridesKey) as? [String: Any] ?? [String: Any]()
        DDLogInfo("[AppSelectorBar] Current AppOverrides keys: \(appOverrides.keys)")
        
        let escapedBundleID = bundleID.replacingOccurrences(of: ".", with: "\\.")
        
        var maxOrder = 0
        for (_, val) in appOverrides {
            if let appDict = val as? [String: Any],
               let meta = appDict["meta"] as? [String: Any],
               let order = meta["scrollOverridePanelTableViewOrderKey"] as? Int {
                maxOrder = max(maxOrder, order)
            }
        }
        
        let newAppDict: [String: Any] = [
            "Root": [String: Any](),
            "meta": [
                "scrollOverridePanelTableViewOrderKey": maxOrder + 1
            ]
        ]
        
        DDLogInfo("[AppSelectorBar] Calling setConfig for AppOverrides.\(escapedBundleID)")
        setConfig("AppOverrides.\(escapedBundleID)", newAppDict as NSObject)
        commitConfig()
        
        DDLogInfo("[AppSelectorBar] Config committed. Calling setUIAppOverrideBundleID")
        Config.setUIAppOverrideBundleID(bundleID)
        ReactiveConfig.shared.react(newConfig: Config.shared.config)
        
        self.appSelectorBar?.selectApp(bundleID: bundleID)
        DDLogInfo("[AppSelectorBar] addApplicationOverride completed successfully")
    }
    
    func removeApplicationActionExternal(bundleID: String) {
        let escapedBundleID = bundleID.replacingOccurrences(of: ".", with: "\\.")
        removeFromConfig("AppOverrides.\(escapedBundleID)")
        commitConfig()
        
        Config.setUIAppOverrideBundleID(nil)
        ReactiveConfig.shared.react(newConfig: Config.shared.config)
        
        self.appSelectorBar?.selectApp(bundleID: nil)
    }
    
    private func addApplicationAction() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.allowsMultipleSelection = false
        if #available(macOS 13.0, *) {
            openPanel.allowedContentTypes = [.application]
        } else {
            openPanel.allowedFileTypes = ["app"]
        }
        openPanel.prompt = "添加"
        
        let appsURL = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first
        openPanel.directoryURL = appsURL
        
        openPanel.beginSheetModal(for: self.view.window!) { result in
            if result == .OK, let fileURL = openPanel.url {
                let bundleID = Bundle(url: fileURL)?.bundleIdentifier ?? "path:" + (fileURL.path as NSString).standardizingPath
                if !bundleID.isEmpty {
                    let appOverridesKey = "AppOverrides"
                    var appOverrides = Config.shared.config.object(forKey: appOverridesKey) as? [String: Any] ?? [String: Any]()
                    
                    let escapedBundleID = bundleID.replacingOccurrences(of: ".", with: "\\.")
                    
                    var maxOrder = 0
                    for (_, val) in appOverrides {
                        if let appDict = val as? [String: Any],
                           let meta = appDict["meta"] as? [String: Any],
                           let order = meta["scrollOverridePanelTableViewOrderKey"] as? Int {
                            maxOrder = max(maxOrder, order)
                        }
                    }
                    
                    let newAppDict: [String: Any] = [
                        "Root": [String: Any](),
                        "meta": [
                            "scrollOverridePanelTableViewOrderKey": maxOrder + 1
                        ]
                    ]
                    
                    setConfig("AppOverrides.\(escapedBundleID)", newAppDict as NSObject)
                    commitConfig()
                    
                    Config.setUIAppOverrideBundleID(bundleID)
                    ReactiveConfig.shared.react(newConfig: Config.shared.config)
                    
                    self.appSelectorBar?.selectApp(bundleID: bundleID)
                }
            } else {
                self.appSelectorBar?.reloadData()
            }
        }
    }
    
    private func removeCurrentApplicationAction() {
        guard let currentOverride = Config.uiAppOverrideBundleID() else { return }
        
        let escapedBundleID = currentOverride.replacingOccurrences(of: ".", with: "\\.")
        removeFromConfig("AppOverrides.\(escapedBundleID)")
        commitConfig()
        
        Config.setUIAppOverrideBundleID(nil)
        ReactiveConfig.shared.react(newConfig: Config.shared.config)
        
        self.appSelectorBar?.selectApp(bundleID: nil)
    }
}

// MARK: - AppOverrideViewController Custom UI Controller
class AppOverrideViewController: NSViewController {
    
    weak var mainTabVC: TabViewController?
    
    var contentWrapView: NSView!
    var appSelectorBar: AppSelectorBar!
    var segmentControl: NSSegmentedControl!
    var containerView: NSView!
    private var placeholderTextField: NSTextField?
    private var placeholderWidthConstraint: NSLayoutConstraint?
    private var placeholderHeightConstraint: NSLayoutConstraint?
    
    /// Hardcoded width for the apps tab, matching the style of applyHardcodedTabWidth() for other tabs.
    /// This prevents the view from expanding freely when resizeWindowToFit() temporarily sets window to 99999x99999.
    static let hardcodedWidth: CGFloat = 420
    
    override func loadView() {
        let view = NSView()
        view.wantsLayer = true
        self.view = view
        
        contentWrapView = NSView()
        contentWrapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentWrapView)
        
        // 1. AppSelectorBar
        appSelectorBar = AppSelectorBar()
        appSelectorBar.translatesAutoresizingMaskIntoConstraints = false
        appSelectorBar.delegate = mainTabVC
        contentWrapView.addSubview(appSelectorBar)
        
        // 2. Segmented Control
        segmentControl = NSSegmentedControl(labels: ["按键", "滚动"], trackingMode: .selectOne, target: self, action: #selector(segmentChanged(_:)))
        segmentControl.translatesAutoresizingMaskIntoConstraints = false
        segmentControl.selectedSegment = 0
        contentWrapView.addSubview(segmentControl)
        
        // 3. Container View
        containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentWrapView.addSubview(containerView)
        
        /// Apply hardcoded width to prevent unconstrained expansion during window resize measurement.
        /// Without this, when resizeWindowToFit() sets window to 99999x99999, this view expands to fill that space.
        let widthConstraint = view.widthAnchor.constraint(equalToConstant: AppOverrideViewController.hardcodedWidth)
        widthConstraint.isActive = true
        
        /// Minimum height for containerView so that fittingSize includes a reasonable content area.
        /// Without this, fittingSize only counts required-priority constraints and the containerView
        /// would collapse to zero height when empty.
        let containerMinHeight = containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200)
        containerMinHeight.isActive = true
        
        NSLayoutConstraint.activate([
            contentWrapView.topAnchor.constraint(equalTo: view.topAnchor),
            contentWrapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentWrapView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            contentWrapView.widthAnchor.constraint(equalToConstant: AppOverrideViewController.hardcodedWidth),
            
            // AppSelectorBar at top
            appSelectorBar.leadingAnchor.constraint(equalTo: contentWrapView.leadingAnchor),
            appSelectorBar.trailingAnchor.constraint(equalTo: contentWrapView.trailingAnchor),
            appSelectorBar.topAnchor.constraint(equalTo: contentWrapView.topAnchor),
            appSelectorBar.heightAnchor.constraint(equalToConstant: 60),
            
            // SegmentControl in the middle
            segmentControl.centerXAnchor.constraint(equalTo: contentWrapView.centerXAnchor),
            segmentControl.topAnchor.constraint(equalTo: appSelectorBar.bottomAnchor, constant: 12),
            
            // ContainerView at bottom
            containerView.leadingAnchor.constraint(equalTo: contentWrapView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentWrapView.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: segmentControl.bottomAnchor, constant: 12),
            containerView.bottomAnchor.constraint(equalTo: contentWrapView.bottomAnchor)
        ])
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @objc func segmentChanged(_ sender: NSSegmentedControl) {
        embedViewForCurrentSegment()
        
        // Trigger a window resize animation to fit the newly embedded view
        if let tabVC = mainTabVC,
           let selectedItem = tabVC.tabView.selectedTabViewItem,
           (selectedItem.identifier as? String) == "apps" {
            _ = tabVC.resizeWindowToFit(tabViewItem: selectedItem)
        }
    }
    
    private func restoreEmbeddedTabViewVisibility(_ view: NSView) {
        view.alphaValue = 1.0
        view.subviews.first?.alphaValue = 1.0
    }
    
    func embedViewForCurrentSegment() {
        placeholderTextField?.removeFromSuperview()
        placeholderTextField = nil
        
        if let wc = placeholderWidthConstraint {
            NSLayoutConstraint.deactivate([wc])
            placeholderWidthConstraint = nil
        }
        if let hc = placeholderHeightConstraint {
            NSLayoutConstraint.deactivate([hc])
            placeholderHeightConstraint = nil
        }
        
        guard let tabVC = mainTabVC else { return }
        
        if appSelectorBar.selectedBundleID == nil {
            segmentControl.isHidden = true
            
            for sv in containerView.subviews {
                sv.removeFromSuperview()
            }
            NSLayoutConstraint.deactivate(tabVC.buttonsVCEmbedConstraints)
            tabVC.buttonsVCEmbedConstraints.removeAll()
            NSLayoutConstraint.deactivate(tabVC.scrollingVCEmbedConstraints)
            tabVC.scrollingVCEmbedConstraints.removeAll()
            
            let tf = NSTextField(wrappingLabelWithString: "未添加应用配置\n点击右上角的 + 按钮，为特定应用自定义独立的按键和滚动设置")
            tf.alignment = .center
            tf.font = NSFont.systemFont(ofSize: 13)
            tf.textColor = NSColor.secondaryLabelColor
            tf.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(tf)
            
            let wc = containerView.widthAnchor.constraint(equalToConstant: 330)
            let hc = containerView.heightAnchor.constraint(equalToConstant: 250)
            hc.priority = .defaultLow
            NSLayoutConstraint.activate([
                tf.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                tf.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                tf.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 20),
                tf.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -20),
                wc, hc
            ])
            placeholderTextField = tf
            placeholderWidthConstraint = wc
            placeholderHeightConstraint = hc
            return
        }
        
        segmentControl.isHidden = false
        
        // Remove existing subviews from containerView
        for sv in containerView.subviews {
            sv.removeFromSuperview()
        }
        
        // Deactivate old constraints to avoid conflicting constraints
        NSLayoutConstraint.deactivate(tabVC.buttonsVCEmbedConstraints)
        tabVC.buttonsVCEmbedConstraints.removeAll()
        
        NSLayoutConstraint.deactivate(tabVC.scrollingVCEmbedConstraints)
        tabVC.scrollingVCEmbedConstraints.removeAll()
        
        if segmentControl.selectedSegment == 0 {
            if let view = tabVC.buttonsVC?.view {
                guard tabVC.validateContentInstall(view, into: containerView, tabViewItem: NSTabViewItem(identifier: "apps")) else {
                    #if DEBUG
                    assertionFailure("Refusing to install invalid tab content view under AppOverrideViewController.")
                    #endif
                    return
                }
                
                view.removeFromSuperview()
                containerView.addSubview(view)
                restoreEmbeddedTabViewVisibility(view)
                view.translatesAutoresizingMaskIntoConstraints = false
                let constraints = [
                    view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                    view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                    view.topAnchor.constraint(equalTo: containerView.topAnchor),
                    view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
                ]
                NSLayoutConstraint.activate(constraints)
                tabVC.buttonsVCEmbedConstraints = constraints
                
                if let buttonTabVC = tabVC.buttonsVC as? ButtonTabController {
                    buttonTabVC.view.needsLayout = true
                    buttonTabVC.view.layoutSubtreeIfNeeded()
                    buttonTabVC.tableView?.updateSize(withAnimation: false, tabContentView: buttonTabVC.view)
                }
            }
        } else {
            if let view = tabVC.scrollingVC?.view {
                guard tabVC.validateContentInstall(view, into: containerView, tabViewItem: NSTabViewItem(identifier: "apps")) else {
                    #if DEBUG
                    assertionFailure("Refusing to install invalid tab content view under AppOverrideViewController.")
                    #endif
                    return
                }
                
                view.removeFromSuperview()
                containerView.addSubview(view)
                restoreEmbeddedTabViewVisibility(view)
                view.translatesAutoresizingMaskIntoConstraints = false
                let constraints = [
                    view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                    view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                    view.topAnchor.constraint(equalTo: containerView.topAnchor),
                    view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
                ]
                NSLayoutConstraint.activate(constraints)
                tabVC.scrollingVCEmbedConstraints = constraints
                
                tabVC.scrollingVC?.view.needsLayout = true
                tabVC.scrollingVC?.view.layoutSubtreeIfNeeded()
            }
        }
    }
}

// MARK: - AppInfo
struct AppInfo {
    let name: String
    let icon: NSImage
}

// MARK: - AppSelectorBar Custom UI Control
class AppSelectorBar: NSView {
    
    private var scrollView: NSScrollView!
    private var stackView: NSStackView!
    private var addButton: NSButton!
    private var heightConstraint: NSLayoutConstraint!
    private var popover: NSPopover?
    private var renderedBundleIDs: [String] = []
    private var renderedSelectedBundleID: String?
    
    // Cache to avoid slow URLForApplication and icon resolver lookups
    static var appInfoCache: [String: AppInfo] = [:]
    
    weak var delegate: TabViewController?
    var selectedBundleID: String? = nil
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func getSymbolImage(name: String, fallbackName: String) -> NSImage {
        if #available(macOS 11.0, *) {
            if let img = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
                return img
            }
        }
        return NSImage(named: fallbackName) ?? NSImage()
    }
    
    private func setupUI() {
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        self.addSubview(scrollView)
        
        stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.spacing = 12
        stackView.edgeInsets = NSEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        stackView.alignment = .centerY
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.documentView = stackView
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.contentView.heightAnchor)
        ])
        
        let addImg = getSymbolImage(name: "plus", fallbackName: "NSAddTemplate")
        addButton = NSButton(image: addImg, target: self, action: #selector(addAppClicked))
        addButton.bezelStyle = .texturedRounded
        addButton.isBordered = true
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.widthAnchor.constraint(equalToConstant: 32).isActive = true
        addButton.heightAnchor.constraint(equalToConstant: 32).isActive = true
        self.addSubview(addButton)
        
        let line = NSView()
        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor.separatorColor.cgColor
        line.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(line)
        
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: addButton.leadingAnchor, constant: -8),
            scrollView.topAnchor.constraint(equalTo: self.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            
            addButton.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),
            addButton.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            
            line.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            line.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            line.heightAnchor.constraint(equalToConstant: 1)
        ])
    }
    
    func setHeight(_ targetHeight: CGFloat, animated: Bool) {
        if heightConstraint == nil {
            for constraint in self.constraints {
                if constraint.firstAttribute == .height {
                    heightConstraint = constraint
                    break
                }
            }
        }
        
        guard let hc = heightConstraint else { return }
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                hc.animator().constant = targetHeight
                self.animator().alphaValue = targetHeight > 0 ? 1.0 : 0.0
            }
        } else {
            hc.constant = targetHeight
            self.alphaValue = targetHeight > 0 ? 1.0 : 0.0
        }
    }
    
    private func getAppInfo(for bundleID: String) -> AppInfo {
        if let cached = AppSelectorBar.appInfoCache[bundleID] {
            return cached
        }
        
        var appName = bundleID
        var appIcon: NSImage? = nil
        
        if let path = AppSelectorBar.pathBackedAppIdentifierPath(bundleID) {
            appName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            appIcon = NSWorkspace.shared.icon(forFile: path)
        } else if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let appPath = appURL.path
            appName = (Bundle(path: appPath)?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                      ?? appURL.deletingPathExtension().lastPathComponent
            appIcon = NSWorkspace.shared.icon(forFile: appPath)
        }
        
        if appIcon == nil {
            if #available(macOS 11.0, *) {
                appIcon = NSImage(systemSymbolName: "application", accessibilityDescription: nil)
            } else {
                appIcon = NSImage(named: "NSApplicationIcon")
            }
        }
        
        let info = AppInfo(name: appName, icon: appIcon!)
        AppSelectorBar.appInfoCache[bundleID] = info
        return info
    }
    
    func reloadData() {
        DDLogInfo("[AppSelectorBar] reloadData called. selectedBundleID: \(String(describing: selectedBundleID))")
        var sortedKeys: [String] = []
        let configDict = Config.shared.config
        if let appOverrides = configDict.object(forKey: "AppOverrides") as? NSDictionary {
            sortedKeys = appOverrides.allKeys.compactMap { $0 as? String }.sorted()
            DDLogInfo("[AppSelectorBar] reloadData: Found AppOverrides keys: \(sortedKeys)")
            
            // 如果当前选择为 nil 且有自定义应用，自动选中第一个
            if (selectedBundleID == nil || !sortedKeys.contains(selectedBundleID!)) && !sortedKeys.isEmpty {
                let defaultApp = sortedKeys.first!
                self.selectedBundleID = defaultApp
                Config.setUIAppOverrideBundleID(defaultApp)
                ReactiveConfig.shared.react(newConfig: configDict)
                delegate?.appSelectorChangedExternal()
            }
        } else {
            DDLogInfo("[AppSelectorBar] reloadData: AppOverrides is nil in config")
        }
        
        if renderedBundleIDs == sortedKeys && renderedSelectedBundleID == selectedBundleID {
            return
        }
        
        for view in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        for bundleID in sortedKeys {
            let info = getAppInfo(for: bundleID)
            let btn = createAppButton(title: info.name, bundleID: bundleID, icon: info.icon)
            stackView.addArrangedSubview(btn)
        }
        renderedBundleIDs = sortedKeys
        renderedSelectedBundleID = selectedBundleID
        self.needsLayout = true
        stackView.needsLayout = true
    }
    
    private func createAppButton(title: String, bundleID: String?, icon: NSImage) -> NSView {
        let isSelected = (bundleID == selectedBundleID)
        
        let container = NSButton()
        container.title = ""
        container.isBordered = false
        container.imagePosition = .imageOnly
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let normIcon = icon.copy() as! NSImage
        normIcon.size = NSSize(width: 32, height: 32)
        container.image = normIcon
        
        container.target = self
        container.action = #selector(appItemClicked(_:))
        
        let wrapper = NSView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.wantsLayer = true
        wrapper.layer?.cornerRadius = 22 // Perfectly circular
        wrapper.toolTip = title
        
        if isSelected {
            wrapper.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
            wrapper.layer?.borderWidth = 1.5
            wrapper.layer?.borderColor = NSColor.controlAccentColor.cgColor
        } else {
            wrapper.layer?.backgroundColor = NSColor.clear.cgColor
            wrapper.layer?.borderWidth = 0
        }
        
        wrapper.addSubview(container)
        
        NSLayoutConstraint.activate([
            wrapper.widthAnchor.constraint(equalToConstant: 44),
            wrapper.heightAnchor.constraint(equalToConstant: 44),
            
            container.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
            container.widthAnchor.constraint(equalToConstant: 32),
            container.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        if let bid = bundleID {
            let menu = NSMenu()
            let deleteItem = NSMenuItem(title: "删除该配置 🗑️", action: #selector(deleteAppOverride(_:)), keyEquivalent: "")
            deleteItem.target = self
            deleteItem.representedObject = bid
            menu.addItem(deleteItem)
            wrapper.menu = menu
        }
        
        objc_setAssociatedObject(container, &AssociatedKeys.bundleID, bundleID, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        return wrapper
    }
    
    @objc private func appItemClicked(_ sender: NSButton) {
        let bundleID = objc_getAssociatedObject(sender, &AssociatedKeys.bundleID) as? String
        self.selectedBundleID = bundleID
        
        Config.setUIAppOverrideBundleID(bundleID)
        ReactiveConfig.shared.react(newConfig: Config.shared.config)
        reloadData()
        
        delegate?.appSelectorChangedExternal()
    }
    
    @objc private func addAppClicked() {
        DDLogInfo("[AppSelectorBar] addAppClicked triggered")
        let pickerVC = AppPickerViewController()
        
        if self.window == nil {
            DDLogInfo("[AppSelectorBar] Error: AppSelectorBar window is nil!")
        }
        if addButton.window == nil {
            DDLogInfo("[AppSelectorBar] Error: addButton window is nil!")
        }
        
        pickerVC.onSelectApp = { [weak self] bundleID in
            DDLogInfo("[AppSelectorBar] onSelectApp: \(bundleID)")
            self?.popover?.performClose(nil)
            self?.delegate?.addApplicationOverride(bundleID: bundleID)
        }
        pickerVC.onBrowseFiles = { [weak self] in
            DDLogInfo("[AppSelectorBar] onBrowseFiles triggered")
            self?.popover?.performClose(nil)
            self?.delegate?.addApplicationActionExternal()
        }
        
        let pop = NSPopover()
        pop.contentViewController = pickerVC
        pop.behavior = .transient
        pop.show(relativeTo: addButton.bounds, of: addButton, preferredEdge: .maxY)
        self.popover = pop
        DDLogInfo("[AppSelectorBar] Popover shown: \(String(describing: self.popover))")
    }
    
    @objc private func deleteAppOverride(_ sender: NSMenuItem) {
        guard let bid = sender.representedObject as? String else { return }
        delegate?.removeApplicationActionExternal(bundleID: bid)
    }
    
    func selectApp(bundleID: String?) {
        self.selectedBundleID = bundleID
        reloadData()
    }
    
    static func appOverrideIdentifier(for app: NSRunningApplication) -> String? {
        if let bundleID = app.bundleIdentifier, !bundleID.isEmpty {
            return bundleID
        }
        if let path = app.bundleURL?.path, !path.isEmpty {
            return "path:" + (path as NSString).standardizingPath
        }
        return nil
    }
    
    static func pathBackedAppIdentifierPath(_ identifier: String) -> String? {
        guard identifier.hasPrefix("path:") else { return nil }
        return String(identifier.dropFirst("path:".count))
    }
}

// MARK: - AppPickerViewController Custom UI Controller
class AppPickerViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    var searchField: NSSearchField!
    var scrollView: NSScrollView!
    var tableView: NSTableView!
    var browseButton: NSButton!
    
    var onSelectApp: ((String) -> Void)?
    var onBrowseFiles: (() -> Void)?
    
    private var runningApps: [NSRunningApplication] = []
    private var filteredApps: [NSRunningApplication] = []
    private var workspaceNotificationObservers: [NSObjectProtocol] = []
    private var refreshTimer: Timer?
    
    override func loadView() {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 360))
        view.wantsLayer = true
        self.view = view
        self.preferredContentSize = NSSize(width: 280, height: 360)
        
        // 1. Search Field
        searchField = NSSearchField()
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "搜索正在运行的应用..."
        searchField.delegate = self
        view.addSubview(searchField)
        
        // 2. Scroll View & Table View
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        view.addSubview(scrollView)
        
        tableView = NSTableView()
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 36
        tableView.target = self
        tableView.action = #selector(tableViewClicked)
        if #available(macOS 11.0, *) {
            tableView.style = .fullWidth
        }
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("AppColumn"))
        column.width = 260
        tableView.addTableColumn(column)
        scrollView.documentView = tableView
        
        // 3. Browse Button
        browseButton = NSButton(title: "浏览其他应用...", target: self, action: #selector(browseFilesClicked))
        browseButton.bezelStyle = .rounded
        browseButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(browseButton)
        
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            searchField.heightAnchor.constraint(equalToConstant: 24),
            
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            
            browseButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 8),
            browseButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            browseButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            browseButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
            browseButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        startObservingWorkspaceChanges()
        loadRunningApplications()
    }
    
    deinit {
        refreshTimer?.invalidate()
        let notificationCenter = NSWorkspace.shared.notificationCenter
        for observer in workspaceNotificationObservers {
            notificationCenter.removeObserver(observer)
        }
    }
    
    private func startObservingWorkspaceChanges() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        let notifications: [NSNotification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification
        ]
        workspaceNotificationObservers = notifications.map { name in
            notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.loadRunningApplications()
            }
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.loadRunningApplications()
        }
    }
    
    private func loadRunningApplications() {
        DDLogInfo("[AppPickerViewController] loadRunningApplications started")
        var seen = Set<String>()
        var list: [NSRunningApplication] = []
        for app in NSWorkspace.shared.runningApplications {
            guard let identifier = AppSelectorBar.appOverrideIdentifier(for: app),
                  app.localizedName != nil || app.bundleURL != nil else { continue }
            if identifier == Bundle.main.bundleIdentifier {
                continue
            }
            if app.activationPolicy == .prohibited && !AppPickerViewController.shouldShowProhibitedApplication(app) {
                continue
            }
            if !seen.contains(identifier) {
                seen.insert(identifier)
                list.append(app)
            }
        }
        list.sort { ($0.localizedName ?? "").localizedCaseInsensitiveCompare($1.localizedName ?? "") == .orderedAscending }
        self.runningApps = list
        applyFilter()
        DDLogInfo("[AppPickerViewController] Found \(list.count) running apps to display")
        tableView.reloadData()
    }
    
    private static func shouldShowProhibitedApplication(_ app: NSRunningApplication) -> Bool {
        let name = app.localizedName ?? ""
        let path = app.bundleURL?.path ?? ""
        let executableName = app.executableURL?.lastPathComponent ?? ""
        return name.localizedCaseInsensitiveContains("java")
            || path.localizedCaseInsensitiveContains("java")
            || path.localizedCaseInsensitiveContains("minecraft")
            || executableName.localizedCaseInsensitiveContains("java")
    }
    
    func controlTextDidChange(_ obj: Notification) {
        applyFilter()
        tableView.reloadData()
    }
    
    private func applyFilter() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            filteredApps = runningApps
        } else {
            filteredApps = runningApps.filter { app in
                let name = app.localizedName ?? ""
                let bundleID = app.bundleIdentifier ?? ""
                let path = app.bundleURL?.path ?? ""
                let executableName = app.executableURL?.lastPathComponent ?? ""
                return name.localizedCaseInsensitiveContains(query)
                    || bundleID.localizedCaseInsensitiveContains(query)
                    || path.localizedCaseInsensitiveContains(query)
                    || executableName.localizedCaseInsensitiveContains(query)
            }
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredApps.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let app = filteredApps[row]
        let cellID = NSUserInterfaceItemIdentifier("AppCell")
        
        var cell = tableView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = cellID
            
            let imgView = NSImageView()
            imgView.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(imgView)
            cell?.imageView = imgView
            
            let txtField = NSTextField(labelWithString: "")
            txtField.translatesAutoresizingMaskIntoConstraints = false
            txtField.font = NSFont.systemFont(ofSize: 13)
            txtField.lineBreakMode = .byTruncatingTail
            cell?.addSubview(txtField)
            cell?.textField = txtField
            
            NSLayoutConstraint.activate([
                imgView.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4),
                imgView.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                imgView.widthAnchor.constraint(equalToConstant: 24),
                imgView.heightAnchor.constraint(equalToConstant: 24),
                
                txtField.leadingAnchor.constraint(equalTo: imgView.trailingAnchor, constant: 8),
                txtField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -4),
                txtField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
            ])
        }
        
        cell?.imageView?.image = app.icon ?? NSWorkspace.shared.icon(forFile: app.bundleURL?.path ?? "")
        cell?.textField?.stringValue = app.localizedName ?? app.executableURL?.lastPathComponent ?? AppSelectorBar.appOverrideIdentifier(for: app) ?? ""
        return cell
    }
    
    @objc private func tableViewClicked() {
        let clickedRow = tableView.clickedRow
        let selectedRow = tableView.selectedRow
        DDLogInfo("[AppPickerViewController] tableViewClicked. clickedRow: \(clickedRow), selectedRow: \(selectedRow), filteredApps.count: \(filteredApps.count)")
        let row = clickedRow >= 0 ? clickedRow : selectedRow
        guard row >= 0 && row < filteredApps.count else {
            DDLogInfo("[AppPickerViewController] tableViewClicked: row index \(row) out of bounds!")
            return
        }
        let app = filteredApps[row]
        if let bid = AppSelectorBar.appOverrideIdentifier(for: app) {
            let name = app.localizedName ?? app.executableURL?.lastPathComponent ?? bid
            DDLogInfo("[AppPickerViewController] tableViewClicked selected app: \(name) (\(bid))")
            let icon = app.icon ?? NSWorkspace.shared.icon(forFile: "")
            AppSelectorBar.appInfoCache[bid] = AppInfo(name: name, icon: icon)
            if let onSelect = onSelectApp {
                DDLogInfo("[AppPickerViewController] Invoking onSelectApp callback")
                onSelect(bid)
            } else {
                DDLogInfo("[AppPickerViewController] Error: onSelectApp callback is nil!")
            }
        } else {
            DDLogInfo("[AppPickerViewController] Error: selected app has nil bundleIdentifier")
        }
    }
    
    @objc private func browseFilesClicked() {
        onBrowseFiles?()
    }
}

private struct AssociatedKeys {
    static var bundleID: UInt8 = 0
}
