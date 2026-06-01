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
//        accelerationHint.setCollapsedWithoutAnimation(acceleration.value != "system")
        accelerationHint.reactive.isCollapsed <~ acceleration.map({ acc in
            acc != "system"
        })
        
        setupLogitechUI()
    }
    
    /// Helper
    
    fileprivate func round(_ v: Double, decimals: Double) -> Double {
        let a: Double = pow(10, decimals)
        return Darwin.round(v*a)/a
    }
    
    // Programmatic Logitech Mouse Info Outlets
    private var logiInfoStack: NSStackView!
    private var batteryIcon: NSImageView!
    private var batteryLabel: NSTextField!
    private var dpiIcon: NSImageView!
    private var dpiLabel: NSTextField!
    private var queryTimer: Timer?
    
    private func setupLogitechUI() {
        let infoStack = NSStackView()
        infoStack.orientation = .horizontal
        infoStack.alignment = .centerY
        infoStack.spacing = 20
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        
        let batteryStack = NSStackView()
        batteryStack.orientation = .horizontal
        batteryStack.alignment = .centerY
        batteryStack.spacing = 6
        
        let bIcon = NSImageView()
        if #available(macOS 11.0, *) {
            bIcon.image = NSImage(systemSymbolName: "battery.100", accessibilityDescription: "Battery")
        }
        bIcon.contentTintColor = .secondaryLabelColor
        bIcon.translatesAutoresizingMaskIntoConstraints = false
        bIcon.widthAnchor.constraint(equalToConstant: 18).isActive = true
        bIcon.heightAnchor.constraint(equalToConstant: 18).isActive = true
        self.batteryIcon = bIcon
        
        let bLabel = NSTextField(labelWithString: "Battery: --")
        bLabel.textColor = .secondaryLabelColor
        bLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        self.batteryLabel = bLabel
        
        batteryStack.addArrangedSubview(bIcon)
        batteryStack.addArrangedSubview(bLabel)
        
        let dpiStack = NSStackView()
        dpiStack.orientation = .horizontal
        dpiStack.alignment = .centerY
        dpiStack.spacing = 6
        
        let dIcon = NSImageView()
        if #available(macOS 11.0, *) {
            dIcon.image = NSImage(systemSymbolName: "speedometer", accessibilityDescription: "DPI")
        }
        dIcon.contentTintColor = .secondaryLabelColor
        dIcon.translatesAutoresizingMaskIntoConstraints = false
        dIcon.widthAnchor.constraint(equalToConstant: 18).isActive = true
        dIcon.heightAnchor.constraint(equalToConstant: 18).isActive = true
        self.dpiIcon = dIcon
        
        let dLabel = NSTextField(labelWithString: "DPI: --")
        dLabel.textColor = .secondaryLabelColor
        dLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        self.dpiLabel = dLabel
        
        dpiStack.addArrangedSubview(dIcon)
        dpiStack.addArrangedSubview(dLabel)
        
        infoStack.addArrangedSubview(batteryStack)
        infoStack.addArrangedSubview(dpiStack)
        
        self.logiInfoStack = infoStack
        
        /// Add as arranged subview of CollapsingStackView (accelerationStack)
        /// But we do NOT call setCollapsed or isCollapsed on it.
        /// We only use plain .isHidden to toggle it.
        accelerationStack.addArrangedSubview(infoStack)
        
        /// Start hidden; polling will show it if a Logitech device is detected
        infoStack.isHidden = true
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        startPolling()
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        stopPolling()
    }
    
    private func startPolling() {
        queryTimer?.invalidate()
        queryTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.pollLogitechInfo()
        }
        /// Dispatch the first poll async so it doesn't block the tab transition
        DispatchQueue.main.async { [weak self] in
            self?.pollLogitechInfo()
        }
    }
    
    private func stopPolling() {
        queryTimer?.invalidate()
        queryTimer = nil
    }
    
    private func pollLogitechInfo() {
        guard let response = MFMessagePort.sendMessage("queryLogitechInfo", withPayload: nil, waitForReply: true) as? [String: Any] else {
            updateLogitechUI(isLogitech: false, batteryPercentage: -1, batteryStatus: -1, dpi: -1)
            return
        }
        
        let isLogitech = response["isLogitech"] as? Bool ?? false
        let batteryPercentage = response["batteryPercentage"] as? Int ?? -1
        let batteryStatus = response["batteryStatus"] as? Int ?? -1
        let dpi = response["dpi"] as? Int ?? -1
        
        updateLogitechUI(isLogitech: isLogitech, batteryPercentage: batteryPercentage, batteryStatus: batteryStatus, dpi: dpi)
    }
    
    private func updateLogitechUI(isLogitech: Bool, batteryPercentage: Int, batteryStatus: Int, dpi: Int) {
        /// Use plain isHidden — no CollapsingStackView collapse system
        if !isLogitech {
            self.logiInfoStack.isHidden = true
            return
        }
        
        self.logiInfoStack.isHidden = false
        
        // Update battery
        if batteryPercentage >= 0 {
            var statusString = ""
            var iconName = "battery.100"
            
            // Map HID++ 2.0 battery status
            if batteryStatus == 1 {
                statusString = " (Charging)"
                iconName = "battery.100.bolt"
            } else if batteryStatus == 2 {
                statusString = " (Full)"
                iconName = "battery.100"
            } else if batteryPercentage <= 10 {
                iconName = "battery.0"
            } else if batteryPercentage <= 35 {
                iconName = "battery.25"
            } else if batteryPercentage <= 65 {
                iconName = "battery.50"
            } else if batteryPercentage <= 90 {
                iconName = "battery.75"
            }
            
            self.batteryLabel.stringValue = "Battery: \(batteryPercentage)%\(statusString)"
            if #available(macOS 11.0, *) {
                self.batteryIcon.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Battery")
            }
        } else {
            self.batteryLabel.stringValue = "Battery: --"
            if #available(macOS 11.0, *) {
                self.batteryIcon.image = NSImage(systemSymbolName: "battery.100", accessibilityDescription: "Battery")
            }
        }
        
        // Update DPI
        if dpi >= 0 {
            self.dpiLabel.stringValue = "DPI: \(dpi)"
        } else {
            self.dpiLabel.stringValue = "DPI: --"
        }
    }
}
