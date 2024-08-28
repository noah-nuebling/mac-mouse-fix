//
//  ScrollTabController.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 16.06.22.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa
import AppKit

@available(macOS 11.0, *)
class ScrollTabController: NSViewController {
    
    /// Config
    
    var smooth = ConfigValue<String>(configPath: "Scroll.smooth")
    var trackpad = ConfigValue<Bool>(configPath: "Scroll.trackpadSimulation")
    var reverseDirection = ConfigValue<Bool>(configPath: "Scroll.reverseDirection")
    var scrollSpeed = ConfigValue<String>(configPath: "Scroll.speed")
    var precise = ConfigValue<Bool>(configPath: "Scroll.precise")
    var horizontalMod = ConfigValue<UInt>(configPath: "Scroll.modifiers.horizontal")
    var zoomMod = ConfigValue<UInt>(configPath: "Scroll.modifiers.zoom")
    var swiftMod = ConfigValue<UInt>(configPath: "Scroll.modifiers.swift")
    var preciseMod = ConfigValue<UInt>(configPath: "Scroll.modifiers.precise")
    
    /// Also see `ReactiveFlags` is this doesn't work
    
    /// Outlets
    
    @IBOutlet weak var masterStack: CollapsingStackView!
    

    
    
    
    
    @IBOutlet weak var smoothPicker: NSPopUpButton!
    
    @IBOutlet weak var trackpadSection: NSStackView!
    @IBOutlet weak var trackpadToggle: NSButton!
    @IBOutlet weak var trackpadHint: NSTextField!
    
    @IBOutlet weak var reverseDirectionToggle: NSButton!
    
    @IBOutlet weak var speedPicker: NSPopUpButton!
    
    @IBOutlet weak var preciseSection: NSStackView!
    @IBOutlet weak var preciseToggle: NSButton!
    @IBOutlet weak var preciseHint: MarkdownTextField!
    
    @IBOutlet weak var horizontalModField: ModCaptureTextField!
    @IBOutlet weak var zoomModField: ModCaptureTextField!
    @IBOutlet weak var swiftModField: ModCaptureTextField!
    @IBOutlet weak var preciseModField: ModCaptureTextField!
    @IBOutlet weak var restoreDefaultModsButton: NSButton!
    
    /// Did appear
    
    override func viewDidAppear() {
        
        /// Remove focus
        ///     Sometimes, one of the modifierCapture fields is randomly selected. This hopefully prevents that.
        ///     Need to do asynAfter 0.0 seconds for it to work (I think - not well tested) that makes it do it on the next runLoop cycle I think.
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.0, execute: {
            MainAppState.shared.window?.makeFirstResponder(nil)
        })
        
        /// Turn off killswitch
        
        let isDisabled = config("General.scrollKillSwitch") as! Bool /// From the debugger it seems you can only cast NSNumber to bool with as! not with as?. That weird??
        if isDisabled {
            
            /// Turn off killSwitch
            setConfig("General.scrollKillSwitch", false as NSObject)
            commitConfig()
            
            /// Show message to user

            Toasts.showReviveToast(showButtons: false, showScroll: true)
        }
    }
    
    /// Init
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /// There was some reason we don't use viewDidLoad here, and instead we use awakeFromNib. I think it had to do with preventing animations from playing when the app starts right into this tab or sth. But maybe it's just unnecessary.
        /// Edit: The replacing between the macOSHint and the preciseSection broke when we used awakeFromNib. Not totally sure why. Let's hope viewDidLoad works after all.
        
        
        /// Smooth
        
        smooth.bindingTarget <~ smoothPicker.reactive.selectedIdentifiers.map({ $0!.rawValue })
        smoothPicker.reactive.selectedIdentifier <~ smooth.producer.map({ NSUserInterfaceItemIdentifier($0) })
         
        trackpadSection.reactive.isCollapsed <~ smooth.producer.map({ $0 != "high" })
        
        /// Trackpad
        trackpad.bindingTarget <~ trackpadToggle.reactive.boolValues
        trackpadToggle.reactive.boolValue <~ trackpad.producer
        
        /// Natural direction
        reverseDirection.bindingTarget <~ reverseDirectionToggle.reactive.boolValues
        reverseDirectionToggle.reactive.boolValue <~ reverseDirection.producer
        
        /// Scroll speed
        scrollSpeed.bindingTarget <~ speedPicker.reactive.selectedIdentifiers.map({ identifier in
            identifier!.rawValue
        })
        speedPicker.reactive.selectedIdentifier <~ scrollSpeed.producer.map({ NSUserInterfaceItemIdentifier($0) })
        
        /// Precise
        /// Notes:
        /// - Why do we generate the preciseHint text in code instead of setting it in IB?
        /// - TODO: Determine line-width programmatically. (We're telling translators to set the line break to their own taste, to make the layout look good, but now that we expect localizers to use .xcloc files instead of running the app that might be difficult.)
        ///     -> Do the same thing for all UI strings with non-semantic linebreaks. (non-semantic means they linebreak exists to make the layout look good not to separate text logically.)
        precise.bindingTarget <~ preciseToggle.reactive.boolValues
        preciseToggle.reactive.boolValue <~ precise.producer
        let preciseHintRaw = NSLocalizedString("precise-scrolling-hint", comment: "Note: The line break is there so the layout of the Scroll tab doesn't become too wide which looks weird. You can set the linebreak to your own taste. || Hint: if text in your language is typically around X times longer than English, then the lines here probably should not be much longer than X times the English version.")
        preciseHint.attributedStringValue = NSAttributedString(attributedMarkdown: preciseHintRaw.attributed().fillingOutBaseAsHint())!
        
        /// Generate macOS hint string
        /// Notes:
        ///   - Under Ventura, you can open the mouse prefpane with the URL `x-apple.systempreferences:com.apple.Mouse-Settings.extension`, but it only works when a mouse is attached and otherwise it will give weird errors, so we're not using it now. We might want to use it if  we test whether a mouse is attached beforehand, or if future Ventura Betas give less janky errors
        ///     - A nice solution was if we had a reactive `activeDevice` class which we could attach to and update this stuff whenever it changes. See `MessagePortUtility_App.getActiveDeviceInfo()`
        ///   - Pre-Ventura you can open the prefPane with `file:///System/Library/PreferencePanes/Mouse.prefPane` but clicking that link inside the macOSHint just reveals the `.prefPane` file in Finder under Big Sur instead of opening it.
        
        var mouseSettingsURL: NSString
        if #available(macOS 13.0, *) {
            
            mouseSettingsURL = "x-apple.systempreferences:com.apple.Mouse-Settings.extension"
            mouseSettingsURL = "" /// Disable for now (see above)
        } else {
            mouseSettingsURL = "file:///System/Library/PreferencePanes/Mouse.prefPane"
            mouseSettingsURL = "" /// Disable for now (see above)
        }
        let macOSHintRaw = String(format: NSLocalizedString("macos-scrolling-hint", comment: ""), UIStrings.systemSettingsName(), mouseSettingsURL)

        /// Installl the macOSHint.
        ///     We manually make the macOSHint width equal the preciseSection width, because if the width changes the window resizes from the left edge which looks crappy.
        ///     This is a really hacky solution. Move this logic into CollapsableStackView (maybe rename to AnimatingStackView or sth).
        ///         Make a method `register(switchableViews:forArrangedSubview:)` which calculates a size that fits all those views, and then you switch between them with `switchTo(view:)`..
        
        let macOSHint = CoolNSTextField(hintWithAttributedString: NSAttributedString(coolMarkdown: macOSHintRaw, fillOutBase: false)!)
        
        macOSHint.translatesAutoresizingMaskIntoConstraints = false
        macOSHint.setContentHuggingPriority(.required, for: .horizontal)
        macOSHint.setContentHuggingPriority(.required, for: .vertical)
        macOSHint.cell?.wraps = true
        let macOSHintIndent = NSView()
        macOSHintIndent.translatesAutoresizingMaskIntoConstraints = false
        macOSHintIndent.addSubview(macOSHint)
        macOSHint.leadingAnchor.constraint(equalTo: macOSHintIndent/*.layoutMarginsGuide*/.leadingAnchor).isActive = true
        macOSHint.trailingAnchor.constraint(equalTo: macOSHintIndent.trailingAnchor).isActive = true
        macOSHint.topAnchor.constraint(equalTo: macOSHintIndent.topAnchor).isActive = true
        macOSHint.bottomAnchor.constraint(equalTo: macOSHintIndent.bottomAnchor).isActive = true
        preciseSection.needsLayout = true
        preciseSection.window?.layoutIfNeeded()
        let preciseWidth = preciseSection.fittingSize.width
        macOSHintIndent.widthAnchor.constraint(equalToConstant: preciseWidth).isActive = true
        let preciseSectionRetained: NSStackView? = self.preciseSection
        var macOSHintIsDisplaying = false
        if scrollSpeed.get() == "system" {
            self.preciseSection.unanimatedReplace(with: macOSHintIndent)
            macOSHintIsDisplaying = true
        }
        scrollSpeed.producer.skip(first: 1).startWithValues { speed in /// Are we sure to `skip(first: 1)` here?
            if speed == "system" && !macOSHintIsDisplaying {
                self.preciseSection.animatedReplace(with: macOSHintIndent)
                macOSHintIsDisplaying = true
            } else if speed != "system" && macOSHintIsDisplaying {
                macOSHintIndent.animatedReplace(with: preciseSectionRetained!)
                macOSHintIsDisplaying = false
            }
        }
        
        /// Scrollwheel capture notifications
        /// Notes:
        /// - You can find discussion of the design-thoughts behind this inside `getCapturedButtonsAndExcludeButtonsThatAreOnlyCapturedByModifier:`
        /// - How to ship this:
        ///     - We're introducing new localizable strings, so we should ship this in a major update with a Beta version
        ///     - Once we shipped it, we should probably update the Captured Buttons Guide: https://github.com/noah-nuebling/mac-mouse-fix/discussions/112 - or create a new guide.
        
        let modProducer = SignalProducer.combineLatest(horizontalMod.producer, zoomMod.producer, swiftMod.producer, preciseMod.producer) /// We could reuse this down in the Keyboard modifier section, but currently, we're not
        let captureProducer = SignalProducer.combineLatest(smooth.producer, reverseDirection.producer, scrollSpeed.producer, modProducer).combinePrevious()
            
        captureProducer.startWithValues { (previous, current) in
            
            DDLogDebug("ScrollTab - Capture-relevant settings changed")
            
            if let toastedWindow = NSApp.mainWindow {
                
                let (smooth0, reverse0, speed0, mods0) = previous
                let (smooth1, reverse1, speed1, mods1) = current
                
                let (horizontal0, zoom0, swift0, precise0) = mods0
                let (horizontal1, zoom1, swift1, precise1) = mods1
                
                let wasCaptured = smooth0 != "off" || reverse0 || speed0 != "system" || horizontal0 != 0 || zoom0 != 0 || swift0 != 0 || precise0 != 0
                let isCaptured  = smooth1 != "off" || reverse1 || speed1 != "system" || horizontal1 != 0 || zoom1 != 0 || swift1 != 0 || precise1 != 0
                    
                DDLogDebug("ScrollTab - smooth: \(smooth0)->\(smooth1) reverse: \(reverse0)->\(reverse1) speed: \(speed0)->\(speed1) horizontal: \(horizontal0)->\(horizontal1) zoom: \(zoom0)->\(zoom1) swift: \(swift0)->\(swift1) precise: \(precise0)->\(precise1)")
                
                if wasCaptured && !isCaptured {
                    CaptureToasts.showScrollWheelCaptureToast(false)
                }
                if !wasCaptured && isCaptured {
                    CaptureToasts.showScrollWheelCaptureToast(true)
                }
            }
        }
        
        /// Keyboard modifiers
        
        horizontalModField <~ horizontalMod.producer.map({ NSEvent.ModifierFlags(rawValue: $0) })
        horizontalMod <~ horizontalModField.signal.map({ $0.rawValue })
        zoomModField <~ zoomMod.producer.map({ NSEvent.ModifierFlags(rawValue: $0) })
        zoomMod <~ zoomModField.signal.map({ $0.rawValue })
        swiftModField <~ swiftMod.producer.map({ NSEvent.ModifierFlags(rawValue: $0) })
        swiftMod <~ swiftModField.signal.map({ $0.rawValue })
        preciseModField <~ preciseMod.producer.map({ NSEvent.ModifierFlags(rawValue: $0) })
        preciseMod <~ preciseModField.signal.map({ $0.rawValue })
        
        /// Keep these in sync with the `default_config`
        typealias Mods = NSEvent.ModifierFlags
        let defaultH: Mods = [.shift]
        let defaultZ: Mods = [.command]
        let defaultS: Mods = [.control]
        let defaultP: Mods = [.option]
        
        restoreDefaultModsButton.reactive.states.observeValues { state in
            self.horizontalMod.set(defaultH.rawValue)
            self.zoomMod.set(defaultZ.rawValue)
            self.swiftMod.set(defaultS.rawValue)
            self.preciseMod.set(defaultP.rawValue)
        }
        
        /// v Using Signal.combineLatest here might be easier.
        ///     Edit: I could do it using combinePrevious() on the modProducer we defined above, but I think it would be much more complicated and less elegant
        
        let allFlags = SignalProducer<(String, UInt), Never>.merge(horizontalMod.producer.map{ ("h", $0) }, zoomMod.producer.map{ ("z", $0) }, swiftMod.producer.map{ ("s", $0) }, preciseMod.producer.map{ ("p", $0) })
        allFlags.startWithValues { (src, flags) in
            
//            DispatchQueue.main.async { /// Need to dispatch async to prevent weird crashes inside ReactiveSwift. Edit: When / why did we comment this out? Seems to not be needed anymore
                
                /// Delete the modifiers which the user just set - delete them for all the other scroll modifications
                ///     So you can't set two different modifications to the same modifier
            
                if self.horizontalMod.get() == flags && src != "h" {
                    self.horizontalMod.set(0)
                }
                if self.zoomMod.get() == flags && src != "z" {
                    self.zoomMod.set(0)
                }
                if self.swiftMod.get() == flags && src != "s" {
                    self.swiftMod.set(0)
                }
                if self.preciseMod.get() == flags && src != "p" {
                    self.preciseMod.set(0)
                }
                
                /// Make restoreDefaults button appear/disappear
            
                var restoreDefaultsIsEnabled = true
                
                if self.horizontalMod.get() == defaultH.rawValue
                    && self.zoomMod.get() == defaultZ.rawValue
                    && self.swiftMod.get() == defaultS.rawValue
                    && self.preciseMod.get() == defaultP.rawValue {
                    
                    restoreDefaultsIsEnabled = false
                }
                
                Animate.with(CABasicAnimation(name: .default, duration: 0.1)) {
                    self.restoreDefaultModsButton.reactiveAnimator().alphaValue.set(restoreDefaultsIsEnabled ? 1.0 : 0.0)
                }
//            }
        }
    }
}
