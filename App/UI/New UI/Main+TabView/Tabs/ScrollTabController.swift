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
    
    var smooth = MutableProperty(true)
    var inertia = MutableProperty(true)
    var naturalDirection = MutableProperty(false)
    var scrollSpeed = MutableProperty("medium")
    var precise = MutableProperty(false)
    var horizontalMod: ReactiveFlags = ReactiveFlags([.shift, .control])
    var zoomMod: ReactiveFlags = ReactiveFlags([])
    var swiftMod: ReactiveFlags = ReactiveFlags([.command])
    var preciseMod: ReactiveFlags = ReactiveFlags([.shift])
    
    /// Outlets
    
    @IBOutlet weak var masterStack: CollapsingStackView!
    
    @IBOutlet weak var smoothToggle: NSButton!
    
    @IBOutlet weak var inertiaSection: NSView!
    @IBOutlet weak var inertiaToggle: NSButton!
    
    @IBOutlet weak var naturalDirectionToggle: NSButton!
    @IBOutlet weak var naturalDirectionHint: NSTextField!
    
    @IBOutlet weak var scrollSpeedPicker: NSPopUpButton!
    
    @IBOutlet weak var preciseSection: NSStackView!
    @IBOutlet weak var preciseToggle: NSButton!
    @IBOutlet weak var preciseHint: NSTextField!
    
    @IBOutlet weak var horizontalModField: ModCaptureTextField!
    @IBOutlet weak var zoomModField: ModCaptureTextField!
    @IBOutlet weak var swiftModField: ModCaptureTextField!
    @IBOutlet weak var preciseModField: ModCaptureTextField!
    @IBOutlet weak var restoreDefaultModsButton: NSButton!
    
    /// Setup
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /// Smooth
        
        smooth.bindingTarget <~ smoothToggle.reactive.boolValues
        smoothToggle.reactive.boolValue <~ smooth.producer
        
        inertiaSection.reactive.isCollapsed <~ smooth.producer.negate()
        
        /// Inertia
        inertia.bindingTarget <~ inertiaToggle.reactive.boolValues
        inertiaToggle.reactive.boolValue <~ inertia.producer
        
        /// Natural direction
        naturalDirection.bindingTarget <~ naturalDirectionToggle.reactive.boolValues
        naturalDirectionToggle.reactive.boolValue <~ naturalDirection.producer
        naturalDirectionHint.stringValue = "Content tracks finger movement"
        
        /// Scroll speed
        scrollSpeed.bindingTarget <~ scrollSpeedPicker.reactive.selectedIdentifiers.map({ identifier in
            identifier!.rawValue
        })
        scrollSpeedPicker.reactive.selectedIdentifier <~ scrollSpeed.producer.map({ speed in
            NSUserInterfaceItemIdentifier.init(rawValue: speed)
        })
        
        /// Precise
        precise.bindingTarget <~ preciseToggle.reactive.boolValues
        preciseToggle.reactive.boolValue <~ precise.producer
        preciseHint.stringValue = "Scroll precisely by moving the scroll wheel slowly"
        
        /// Installl the macOSHint.
        ///     We manually make the macOSHint width equal the preciseSection width, because if the width changes the window resizes from the left edge which looks shitty.
        ///     This is a really shitty solution. Move this logic into CollapsableStackView (maybe rename to AnimatingStackView or sth).
        ///         Make a method `register(switchableViews:forArrangedSubview:)` which calculates a size that fits all those views, and then you switch between them with `switchTo(view:)`.
        let macOSHint = CoolNSTextField(hintWithString: "Set Scroll Speed at\nSystem Settings > Mouse > Scroll Speed")
        macOSHint.translatesAutoresizingMaskIntoConstraints = false
        macOSHint.setContentHuggingPriority(.required, for: .vertical)
        let macOSHintIndent = NSView()
        macOSHintIndent.translatesAutoresizingMaskIntoConstraints = false
        macOSHintIndent.addSubview(macOSHint)
        macOSHint.leadingAnchor.constraint(equalTo: macOSHintIndent/*.layoutMarginsGuide*/.leadingAnchor).isActive = true
        macOSHint.trailingAnchor.constraint(equalTo: macOSHintIndent.trailingAnchor).isActive = true
        macOSHint.topAnchor.constraint(equalTo: macOSHintIndent.topAnchor).isActive = true
        macOSHint.bottomAnchor.constraint(equalTo: macOSHintIndent.bottomAnchor).isActive = true
        preciseSection.needsLayout = true
        preciseSection.window?.layoutIfNeeded()
        macOSHintIndent.widthAnchor.constraint(equalToConstant: preciseSection.fittingSize.width).isActive = true
        let preciseSectionRetained: NSStackView? = self.preciseSection
        var testHintIsDisplaying = false
        scrollSpeed.signal.observeValues { speed in
            if speed == "system" && !testHintIsDisplaying {
                self.preciseSection.animatedReplace(with: macOSHintIndent)
                testHintIsDisplaying = true
            } else if speed != "system" && testHintIsDisplaying{
                macOSHintIndent.animatedReplace(with: preciseSectionRetained!)
                testHintIsDisplaying = false
            }
        }
        
        /// Keyboard modifiers
        
        horizontalModField <~ horizontalMod
        horizontalMod <~ horizontalModField
        zoomModField <~ zoomMod
        zoomMod <~ zoomModField
        swiftModField <~ swiftMod
        swiftMod <~ swiftModField
        preciseModField <~ preciseMod
        preciseMod <~ preciseModField
        
        typealias Mods = NSEvent.ModifierFlags
        let defaultH: Mods = [.shift]
        let defaultZ: Mods = [.command]
        let defaultS: Mods = [.control]
        let defaultP: Mods = [.option]
        
        restoreDefaultModsButton.reactive.states.observeValues { state in
            self.horizontalMod.value = defaultH
            self.zoomMod.value = defaultZ
            self.swiftMod.value = defaultS
            self.preciseMod.value = defaultP
        }
        
        let allFlags = SignalProducer<(String, NSEvent.ModifierFlags), Never>.merge(horizontalMod.flagss.map{ ("h", $0) }, zoomMod.flagss.map{ ("z", $0) }, swiftMod.flagss.map{ ("s", $0) }, preciseMod.flagss.map{ ("p", $0) })
        allFlags.startWithValues { (src, flags) in
            
            DispatchQueue.main.async { /// Need to dispatch async to prevent weird crashes inside ReactiveSwift
                
                if self.horizontalMod.value == flags && src != "h" {
                    self.horizontalMod.value = []
                }
                if self.zoomMod.value == flags && src != "z" {
                    self.zoomMod.value = []
                }
                if self.swiftMod.value == flags && src != "s" {
                    self.swiftMod.value = []
                }
                if self.preciseMod.value == flags && src != "p" {
                    self.preciseMod.value = []
                }
                
                var restoreDefaultsIsEnabled = true
                
                if self.horizontalMod.value == defaultH
                    && self.zoomMod.value == defaultZ
                    && self.swiftMod.value == defaultS
                    && self.preciseMod.value == defaultP {
                    
                    restoreDefaultsIsEnabled = false
                }
                
                Animate.with(CABasicAnimation(name: .default, duration: 0.1)) {
                    self.restoreDefaultModsButton.reactiveAnimator().alphaValue.set(restoreDefaultsIsEnabled ? 1.0 : 0.0)
                }
            }
        }
    }
}
