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

class GeneralTabController: NSViewController {
    
    /// Convenience
//    var enabled: MutableProperty<Bool> { MainAppState.shared.appIsEnabled }
    
    /// Config
    var showInMenubar: MutableProperty<Bool> = MutableProperty(false)
    var checkForUpdates: MutableProperty<Bool> = MutableProperty(false)
    var getBetaVersions: MutableProperty<Bool> = MutableProperty(false)
    
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
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        /// Load data
        showInMenubar.value = false
        checkForUpdates.value = false
        getBetaVersions.value = false
        
        /// Replace enable checkBox with NSSwitch on newer macOS versions
        var usingSwitch = false
        if #available(macOS 10.15, *) {
            
            usingSwitch = true

            let state = enableToggle.value(forKey: "state")

            let switchView = NSSwitcherino()
            
            let superView = enableToggle.superview as! NSStackView
            superView.replaceSubview(enableToggle, with: switchView)
            self.enableToggle = switchView

            self.enableToggle.setValue(state, forKey: "state")
            
            switchView.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        
        /// Declare signals
        
        /// UI <-> data bindings
        let onToggle = { doEnable in
            self.enableToggle.intValue = self.enableToggle.intValue == 0 ? 1 : 0
            if doEnable {
                do {
                    try ReactiveEnabler.shared.enable()
                } catch {
                    if #available(macOS 13, *) {
                        if (error as NSError).code == 1 {
                            let message = NSAttributedString(markdown: "Mac Mouse Fix was **disabled** in System Settings.\nTo enable Mac Mouse Fix:\n\n1. Go to [Login Items Settings](x-apple.systempreferences:com.apple.LoginItems-Settings.extension)\n2. Switch on \'Mac Mouse Fix.app\'")
                            if let window = NSApp.mainWindow {
                                ToastNotificationController.attachNotification(withMessage: message, to: window, forDuration: 0.0)
                            }
                        }
                    }
                }
            } else {
                ReactiveEnabler.shared.disable()
            }
        }
        if usingSwitch, #available(macOS 10.15, *) {
            (enableToggle as? NSSwitcherino)?.reactive.boolValues.startWithValues(onToggle)
        } else {
            enableToggle.reactive.boolValues.observeValues(onToggle)
        }
        
        showInMenubar <~ menuBarToggle.reactive.boolValues
        checkForUpdates <~ updatesToggle.reactive.boolValues
        getBetaVersions <~ betaToggle.reactive.boolValues
        
        if usingSwitch, #available(macOS 10.15, *) {
            (enableToggle as? NSSwitcherino)?.reactive.boolValue <~ ReactiveEnabler.shared
        } else {
            enableToggle.reactive.boolValue <~ ReactiveEnabler.shared
        }
        menuBarToggle.reactive.boolValue <~ showInMenubar
        updatesToggle.reactive.boolValue <~ checkForUpdates
        betaToggle.reactive.boolValue <~ getBetaVersions
        
        mainHidableSection.reactive.isCollapsed <~ ReactiveEnabler.shared.producer.negate()
        updatesExtraSection.reactive.isCollapsed <~ checkForUpdates.negate()
        
        /// Labels
        
        enabledHint.stringValue = NSLocalizedString("Mac Mouse Fix will stay enabled after you\nclose it", comment: "")
        updatesHint.stringValue = NSLocalizedString("You'll see new updates when you open this window", comment: "")
        
//        updatesHint.reactiveAnimator(type: .fade).stringValue <~ checkForUpdates.map { checkUpdates in
//            return checkUpdates ?
//                NSLocalizedString("You'll see new updates when you open this window", comment: "")
//                : NSLocalizedString("You won't see updates", comment: "")
//        }
        
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
    
    required init() {
        let (o, i) = Signal<Bool, Never>.pipe()
        signal = o
        observer = i
        super.init(frame: NSZeroRect)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseDown(with event: NSEvent) {
        self.isHighlighted = true
        let monitorPtr: UnsafeMutablePointer<AnyObject?> = UnsafeMutablePointer.allocate(capacity: 1)
        monitorPtr.pointee = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp, .leftMouseDragged]) { event in
            if event.type == .leftMouseUp {
                self.isHighlighted = false
                if self == self.window?.contentView?.hitTest(event.locationInWindow) {
                    self.state = self.state == .on ? .off : .on
                    self.observer.send(value: (self.state == .on))
                }
                NSEvent.removeMonitor(monitorPtr.pointee!)
            } else {
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
