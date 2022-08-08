//
//  PointerTabItemController.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 24.07.21.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa

class PointerTabController: NSViewController {
    
    /// Config
    
    var sensitivity: MutableProperty<Double> = MutableProperty(0.67)
    var acceleration: MutableProperty<String> = MutableProperty("medium")
    
    /// Outlets

    @IBOutlet weak var sensitivitySlider: NSSlider!
    @IBOutlet weak var sensitivityDisplay: SensitivityDisplay!
    
    @IBOutlet weak var accelerationStack: CollapsingStackView!
    @IBOutlet weak var accelerationPicker: NSPopUpButton!
    @IBOutlet weak var accelerationHint: NSTextField!
    
    /// Init
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /// Sensitivity
        
        /// Configure slider
        let tickmarkValues = [0.5, 0.75, 1.0, 1.5, 2.0]
        let sensitivitySliderCurve = CombinedLinearCurve(yValues: tickmarkValues)
        sensitivitySlider.numberOfTickMarks = tickmarkValues.count
        
        /// Load sensitivity
        self.sensitivity.value = 0.67
        
        /// Setup prop  <-> slider bindings
        sensitivitySlider.reactive.doubleValue <~ sensitivity.producer.map { sensitivitySliderCurve.evaluate(atY: $0) }
        sensitivity <~ sensitivitySlider.reactive.doubleValues.map { sensitivitySliderCurve.evaluate(atX: $0) }
        
        /// Setup prop <-> display bindings
        sensitivityDisplay.reactive.title <~ sensitivity.producer.map{ String(format:"%.2fx", $0) }
        sensitivityDisplay.reactive.values.observeValues { delta in
            var newSens = self.sensitivity.value - (Double(delta) / 400.0)
            let c = sensitivitySliderCurve
            if newSens > c.maxY { newSens = c.maxY }
            if newSens < c.minY { newSens = c.minY }
            self.sensitivity.value = newSens
        }
        
        /// Setup reset
        sensitivityDisplay.resetValue.observeValues { _ in
            let start = self.sensitivitySlider.doubleValue
            self.sensitivity.value = 1.0
            let target = self.sensitivitySlider.doubleValue
            self.sensitivitySlider.doubleValue = start
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.timingFunction = .init(name: .default)
                self.sensitivitySlider.animator().doubleValue = target
            }
        }
                                                        
        /// Acceleration
        
        /// Load acc
        acceleration.value = "low"
        
        /// Setup prop <-> popupButton bindings
        accelerationPicker.reactive.selectedIdentifier <~ acceleration.producer.map { NSUserInterfaceItemIdentifier($0) }
        acceleration <~ accelerationPicker.reactive.selectedIdentifiers.map { $0!.rawValue }
        
        /// Setup prop -> hidableStack binding
        accelerationHint.reactive.isCollapsed <~ acceleration.map({ acc in
            acc != "system"
        })
        
    }
    
    /// Helper
    
    fileprivate func round(_ v: Double, decimals: Double) -> Double {
        let a: Double = pow(10, decimals)
        return Darwin.round(v*a)/a
    }
    
}
