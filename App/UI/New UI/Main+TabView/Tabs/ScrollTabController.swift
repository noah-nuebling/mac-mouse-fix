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
    
    var smooth = ConfigValue<Bool>(configPath: "Scroll.smooth")
    var inertia = ConfigValue<Bool>(configPath: "Scroll.inertia")
    var naturalDirection = ConfigValue<Bool>(configPath: "Scroll.naturalDirection")
    var scrollSpeed = ConfigValue<String>(configPath: "Scroll.speed")
    var precise = ConfigValue<Bool>(configPath: "Scroll.precise")
    var horizontalMod = ConfigValue<UInt>(configPath: "Scroll.modifiers.horizontal")
    var zoomMod = ConfigValue<UInt>(configPath: "Scroll.modifiers.zoom")
    var swiftMod = ConfigValue<UInt>(configPath: "Scroll.modifiers.swift")
    var preciseMod = ConfigValue<UInt>(configPath: "Scroll.modifiers.precise")
    /// Also see `ReactiveFlags` is this doesn't work
    
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
    
    override func awakeFromNib() {
//        super.viewDidLoad()
        super.awakeFromNib()
        
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
        scrollSpeed.producer.skip(first: 1).startWithValues { speed in
            if speed == "system" && !testHintIsDisplaying {
                self.preciseSection.animatedReplace(with: macOSHintIndent)
                testHintIsDisplaying = true
            } else if speed != "system" && testHintIsDisplaying{
                macOSHintIndent.animatedReplace(with: preciseSectionRetained!)
                testHintIsDisplaying = false
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
        
        let allFlags = SignalProducer<(String, UInt), Never>.merge(horizontalMod.producer.map{ ("h", $0) }, zoomMod.producer.map{ ("z", $0) }, swiftMod.producer.map{ ("s", $0) }, preciseMod.producer.map{ ("p", $0) })
        
        allFlags.startWithValues { (src, flags) in
            
//            DispatchQueue.main.async { /// Need to dispatch async to prevent weird crashes inside ReactiveSwift
                
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
