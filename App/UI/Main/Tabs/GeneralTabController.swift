//
//  GeneralTabController.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 23.07.21.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa
import CocoaLumberjackSwift
import Sparkle
import ServiceManagement

class GeneralTabController: NSViewController {
    
    /// Convenience
//    var enabled: MutableProperty<Bool> { MainAppState.shared.appIsEnabled }
    
    /// Config
    var showInMenuBar = ConfigValue<Bool>(configPath: "General.showMenuBarItem")
    var checkForUpdates = ConfigValue<Bool>(configPath: "General.checkForUpdates")
    var getBetaVersions = ConfigValue<Bool>(configPath: "General.checkForPrereleases")
    
    /// Outlets
    
    @IBOutlet var mainView: NSView!
    
    @IBOutlet weak var masterStack: CollapsingStackView!
    
    @IBOutlet weak var enableToggle: NSControl!
    
    @IBOutlet weak var menuBarToggle: NSButton!
    
    @IBOutlet weak var updatesToggle: NSButton!
    @IBOutlet weak var betaToggle: NSButton!
    
    @IBOutlet weak var mainHidableSection: CollapsingStackView!
    @IBOutlet weak var updatesExtraSection: NSView!
    
    
    @IBOutlet weak var enabledHint: NSTextField!
    @IBOutlet weak var updatesHint: NSTextField!
    @IBOutlet weak var menuBarHint: NSTextField!
    
    /// Init
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /// Replace enable checkBox with NSSwitch on newer macOS versions
        var usingSwitch = false
        if #available(macOS 10.15, *) {
            
            usingSwitch = true

            let state = enableToggle.value(forKey: "state")

            let switchView = NSSwitcherino()
            
            let superView = enableToggle.superview as! NSStackView
            superView.replaceSubview(enableToggle, with: switchView)
            NSLayoutConstraint.activate(transferredSuperViewConstraints(fromView: enableToggle, toView: switchView, transferSizeConstraints: false)) /// Currently unnecessary because there are no constraints
            transferHuggingAndCompressionResistance(fromView: enableToggle, toView: switchView)
            
            self.enableToggle = switchView

            self.enableToggle.setValue(state, forKey: "state")
        }
        
        /// 
        /// Sync enabledToggle with Helper enabledState
        ///
        
        let enableTimeout = 3.0
        var enableTimeoutDisposable: Disposable? = nil
        var enableTimeoutTimer: DispatchSourceTimer? = nil
        
        let onToggle = { (doEnable: Bool) in
            
            /// Prevent the enable toggle from toggling when it is clicked
            self.enableToggle.intValue = self.enableToggle.intValue == 0 ? 1 : 0
            
            if doEnable {
                
                let userClickTS = CACurrentMediaTime()
                
                EnabledState.shared.enable(onComplete: { error in
                    
                    if error == nil {
                        
                        /// Notes:
                        /// - Unfortunately there's a whole class of errors with enabling MMF under macOS 13 Ventura and later using the SMAppService API, where the error that the API returns is nil and there seems to be no direct way of finding out that things failed. None of these issues seem to have been fixed currently under macOS 14.2
                        ///     To help the user in these cases:
                        ///     - In the case that the system launches a 'strange' instance of MMF Helper which comes from another version of Mac Mouse Fix. We use `MessagePortUtility.checkHelperStrangenessReact()` to detect that and provide solution steps to the user.
                        ///     - For cases where the system doesn't seem to launch any instance of MMF Helper at all, we set a timout here and then show a toast that refers users to a help page.
                        
                        
                        /// Clean up
                        enableTimeoutDisposable?.dispose()
                        enableTimeoutTimer?.cancel()
                        
                        /// Create a signal that fires when either the app is enabled or a strange helper is detected.
                        let mergedSignal: Signal<Void, Never> = Signal.merge(
                            EnabledState.shared.signal.filter({ $0 == true }).map({ _ in () }),
                            MessagePortUtility.shared.strangeHelperDetected.map({ _ in () })
                        )
                        
                        /// Observe the signal
                        enableTimeoutDisposable = mergedSignal.observeValues({ _ in
                            
                            ///
                            /// Enabling __has not__ timed out
                            ///
                            
                            /// Clean up
                            enableTimeoutDisposable?.dispose()
                            enableTimeoutTimer?.cancel()
                        })
                        
                        /// Set up a timer that fires after `enableTimeout` seconds
                        let timeSinceUserClick = CACurrentMediaTime() - userClickTS
                        let timerFireTime = DispatchTime.now() + enableTimeout - timeSinceUserClick
                        enableTimeoutTimer = DispatchSource.makeTimerSource(flags: [], queue: .main) /// Using main queue here since we're drawing UI from the callback
                        enableTimeoutTimer?.schedule(deadline: timerFireTime)
                        enableTimeoutTimer?.setEventHandler(qos: .userInitiated, flags: [], handler: {
  
                            ///
                            /// Enabling __has__ timed out
                            ///
                            
                            /// Clean up
                            enableTimeoutDisposable?.dispose()
                            
                            /// Show user feedback
                            /// Notes:
                            /// - TODO: Adjust the link after writing the guide.
                            /// - We put a period at the end of this UI string. Usually we don't put periods for short UI strings, but it just feels wrong in this case?
                            /// - The default duration `kMFToastDurationAutomatic` felt too short in this case. I wonder why that is? I think this toast is one of, if not the shortest toasts - maybe it has to do with that? Maybe it feels like it should display longer, because there's a delay until it shows up so it's harder to get back to? Maybe our tastes for how long the toasts should be changed? Maybe we should adjust the formula for `kMFToastDurationAutomatic`?
                            
                            if let window = NSApp.mainWindow {
                                let rawMessage = NSLocalizedString("enable-timeout-toast", comment: "First draft: If you have **problems enabling** the app, click [here](https://github.com/noah-nuebling/mac-mouse-fix/discussions/categories/guides).")
                                ToastNotificationController.attachNotification(withMessage: NSMutableAttributedString(coolMarkdown: rawMessage)!, to: window, forDuration: 10.0)
                            }
                        })
                        enableTimeoutTimer?.resume()
                        
                        
                        
                    } else {
                        
                        guard let error = error else { assert(false); return }
                        
                        var messageRaw = ""
                        if #available(macOS 13.0, *), error.domain == "SMAppServiceErrorDomain", error.code == 1 {
                            messageRaw = NSLocalizedString("is-disabled-toast", comment: "First draft: Mac Mouse Fix was **disabled** in System Settings\n\nTo enable Mac Mouse Fix:\n\n1. Go to [Login Items Settings](x-apple.systempreferences:com.apple.LoginItems-Settings.extension)\n2. Switch on \'Mac Mouse Fix.app\'")
                        }
                        
                        if messageRaw != "" {
                            let message = NSMutableAttributedString(coolMarkdown: messageRaw)
                            DispatchQueue.main.async { /// UI stuff needs to be called from the main thread
                                if let window = NSApp.mainWindow, let message = message {
                                    ToastNotificationController.attachNotification(withMessage: message, to: window, forDuration: kMFToastDurationAutomatic)
                                }
                            }
                            
                        }
                    }
                })
                
            } else { /// !doEnabled
                EnabledState.shared.disable()
            }
        }
        
        if usingSwitch, #available(macOS 10.15, *) {
            (enableToggle as? NSSwitcherino)?.reactive.boolValues.skip(first: 1).startWithValues(onToggle)
        } else {
            enableToggle.reactive.boolValues.observeValues(onToggle) /// Why are we using observe here and startWithValues above?
        }
        
        /// Declare signals
        
        /// UI <-> data bindings
        
        showInMenuBar <~ menuBarToggle.reactive.boolValues
        checkForUpdates <~ updatesToggle.reactive.boolValues
        getBetaVersions <~ betaToggle.reactive.boolValues
        
        if usingSwitch, #available(macOS 10.15, *) {
            (enableToggle as? NSSwitcherino)?.reactive.boolValue <~ EnabledState.shared
        } else {
            enableToggle.reactive.boolValue <~ EnabledState.shared
        }
        menuBarToggle.reactive.boolValue <~ showInMenuBar
        updatesToggle.reactive.boolValue <~ checkForUpdates
        betaToggle.reactive.boolValue <~ getBetaVersions
        
        mainHidableSection.reactive.isCollapsed <~ EnabledState.shared.producer.negate()
        updatesExtraSection.reactive.isCollapsed <~ checkForUpdates.producer.negate()
        
        /// Alert on betaToggle
        /// Notes:
        ///     - Disabling this now, because it's kind of unnecessary, and I don't know how this alert will interact, when a beta Version is acutally available and Sparkle wants to present a sheet as well. Ideally, we would want to present this sheet **before** we toggle the betaToggle, but right now we're just toggling it back if the user doesn't want to toggle it, so Sparkle still gets the message that it's been enabled.
        ///     - The alertStyle should maybe be .warning or sth instead of .informational.
        ///     - We could also put this info into a toas instead of an alert
        ///
        
//        betaToggle.reactive.boolValues.observeValues { betaGotEnabled in
//
//            if betaGotEnabled {
//
//                /// Create alert
//
//                let alert = NSAlert()
//                alert.alertStyle = .informational
//                alert.messageText = NSLocalizedString("beta-alert.title", comment: "First draft: Get Beta Versions?")
//                alert.informativeText = NSLocalizedString("beta-alert.body", comment: "First draft: Beta versions can have many issues.\nDon't forget to give feedback when you run into one.\nThanks!")
//                alert.addButton(withTitle: NSLocalizedString("beta-alert.confirm", comment: "First draft: Get Beta Versions"))
//                alert.addButton(withTitle: NSLocalizedString("beta-alert.back", comment: "First draft: Cancel"))
//
//                /// Display alert
//                guard let window = MainAppState.shared.window else { return }
//                alert.beginSheetModal(for: window) { response in
//                    if response != .alertFirstButtonReturn {
//                        /// Toggle back off
//                        self.betaToggle.state = .off
//                    }
//                }
//            }
//        }
        
        /// Side effects: Sparkle
        ///     See `applicationDidFinishLaunching` for context
        
        checkForUpdates.producer.skip(first: 1).startWithValues { doCheckUpdates in
            UserDefaults.standard.removeObject(forKey: "SUSkippedVersion")
            if doCheckUpdates {
                SUUpdater.shared().checkForUpdatesInBackground()
            }
        }
        getBetaVersions.producer.skip(first: 1).startWithValues { doCheckBetas in
            UserDefaults.standard.removeObject(forKey: "SUSkippedVersion")
            SparkleUpdaterController.enablePrereleaseChannel(doCheckBetas)
            if doCheckBetas {
                SUUpdater.shared().checkForUpdatesInBackground()
            }
        }
    }
}

// MARK: NSSwitcherino

@available(macOS 10.15, *)
extension Reactive where Base: NSSwitcherino {
    
    var boolValue: BindingTarget<Bool> {
        /// Difference to default implementation
        /// - This animates the state change
        
        return BindingTarget(lifetime: base.reactive.lifetime) { newValue in
            if (base.state == .on) != newValue {
                base.performClick(nil)
            }
        }
    }
    var boolValues: SignalProducer<Bool, Never> {
        /// Difference to default implementation
        /// - Doesn't animate when the user clicks
        return base.signal.producer.prefix(value: base.state == .on)
    }
}
@available(macOS 10.15, *)
@objc fileprivate class NSSwitcherino: NSSwitch {
    
    var signal: Signal<Bool, Never>
    var observer: Signal<Bool, Never>.Observer
    var eventMonitor: Any?
    
    required init() {
        let (o, i) = Signal<Bool, Never>.pipe()
        signal = o
        observer = i
        eventMonitor = nil
        super.init(frame: NSZeroRect)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseDown(with event: NSEvent) {
        self.isHighlighted = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp, .leftMouseDragged]) { event in
            if event.type == .leftMouseUp {
                self.isHighlighted = false
                if self == self.window?.contentView?.hitTest(event.locationInWindow) {
                    self.state = self.state == .on ? .off : .on
                    self.observer.send(value: (self.state == .on))
                }
                if let monitor = self.eventMonitor {
                    NSEvent.removeMonitor(monitor)
                    self.eventMonitor = nil
                } else { assert(false) }
            } else { /// mouseDragged event
                if self == self.window?.contentView?.hitTest(event.locationInWindow) {
                    self.isHighlighted = true
                } else {
                    self.isHighlighted = false
                }
            }
            return event
        } as AnyObject?
    }
}
