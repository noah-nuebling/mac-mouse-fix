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
    
    private let accelerationValues: [String: Double] = [
        "off": 0.0,
        "low": 0.25,
        "medium": 0.6875,
        "high": 1.5,
    ]
    private var isLoadingConfig = false
    private var isUpdatingLogitechUI = false
    private var lastLogitechUserChange = Date.distantPast
    
    /// Once we confirm DPI mode (from config or from a successful poll),
    /// never downgrade back to sensitivity mode on transient failures.
    private var confirmedDPIMode = false
    
    /// Init
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /// Sensitivity
        
        /// Configure slider
        let tickmarkValues = [0.5, 0.75, 1.0, 1.5, 2.0]
        let sensitivitySliderCurve = CombinedLinearCurve(yValues: tickmarkValues)
        sensitivitySlider.numberOfTickMarks = tickmarkValues.count
        
        /// Load sensitivity
        self.sensitivity.value = config("Pointer.sensitivity") as? Double ?? 1.0
        
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
        sensitivity.producer.skip(first: 1).startWithValues { [weak self] value in
            guard let self = self else { return }
            guard !self.isLoadingConfig else { return }
            /// Don't write sensitivity config when in DPI mode — prevents accidental leakage
            guard !self.confirmedDPIMode else { return }
            setConfig("Pointer.sensitivity", NSNumber(value: value))
            commitConfig()
        }
                                                        
        /// Acceleration
        
        /// Load acc
        isLoadingConfig = true
        acceleration.value = loadAccelerationIdentifier()
        isLoadingConfig = false
        
        /// Setup prop <-> popupButton bindings
        accelerationPicker.reactive.selectedIdentifier <~ acceleration.producer.map { NSUserInterfaceItemIdentifier($0) }
        acceleration <~ accelerationPicker.reactive.selectedIdentifiers.map { $0!.rawValue }
        acceleration.producer.skip(first: 1).startWithValues { [weak self] value in
            guard let self = self, !self.isLoadingConfig else { return }
            if value == "system" {
                setConfig("Pointer.useSystemAcceleration", NSNumber(value: true))
            } else {
                setConfig("Pointer.useSystemAcceleration", NSNumber(value: false))
                setConfig("Pointer.acceleration", NSNumber(value: self.accelerationValues[value] ?? 0.6875))
            }
            commitConfig()
        }
        
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
    
    private var sensitivityLabel: NSTextField?
    private var sensitivityTickLabels: [NSTextField] = []
    private var dpiSlider: NSSlider!
    private var dpiDisplay: NSButton!
    private var dpiMin: Int = 0
    private var dpiMax: Int = 0
    private var dpiStep: Int = 50
    
    private var logiSettingsStack: NSStackView!
    private var wheelModeControl: NSSegmentedControl!
    private var autoShiftButton: NSButton!
    private var thresholdRow: NSStackView!
    private var thresholdSlider: NSSlider!
    private var thresholdLabel: NSTextField!
    private var torqueRow: NSStackView!
    private var torqueSlider: NSSlider!
    private var torqueLabel: NSTextField!
    
    // HiRes Scroll Wheel
    private var hiResRow: NSStackView!
    private var hiResToggle: NSButton!
    private var confirmedHiResSupport = false
    
    // Report Rate
    private var reportRateRow: NSStackView!
    private var reportRatePopup: NSPopUpButton!
    private var confirmedReportRateSupport = false
    private var reportRateIndexMap: [Int: UInt8] = [:] // popup index → rate index
    private var pendingSmartShiftTimer: Timer?
    
    private func loadAccelerationIdentifier() -> String {
        if config("Pointer.useSystemAcceleration") as? Bool ?? false {
            return "system"
        }
        let accelerationValue = config("Pointer.acceleration") as? Double ?? 0.6875
        return accelerationValues.min { abs($0.value - accelerationValue) < abs($1.value - accelerationValue) }?.key ?? "medium"
    }
    
    private func setupLogitechUI() {
        setupDPIControls()
        setupLogitechSettingsUI()
        
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
        
        let bLabel = NSTextField(labelWithString: MFLocalizedString("pointer-tab.battery.none", comment: "Battery: --"))
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
        
        let dLabel = NSTextField(labelWithString: MFLocalizedString("pointer-tab.dpi.none", comment: "DPI: --"))
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
    
    private func setupDPIControls() {
        guard let wrapper = sensitivitySlider.superview else { return }
        
        let textFields = wrapper.subviews.compactMap { $0 as? NSTextField }
        let sliderFrame = sensitivitySlider.frame
        sensitivityLabel = textFields.first {
            abs($0.frame.midY - sliderFrame.midY) < 12 && $0.frame.maxX <= sliderFrame.minX
        }
        sensitivityTickLabels = textFields.filter {
            $0.frame.midY < sliderFrame.midY &&
            $0.frame.midX >= sliderFrame.minX - 16 &&
            $0.frame.midX <= sliderFrame.maxX + 16
        }
        
        let slider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: self, action: #selector(dpiSliderChanged(_:)))
        slider.isContinuous = true
        slider.numberOfTickMarks = 0
        slider.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(slider)
        NSLayoutConstraint.activate([
            slider.leadingAnchor.constraint(equalTo: sensitivitySlider.leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: sensitivitySlider.trailingAnchor),
            slider.centerYAnchor.constraint(equalTo: sensitivitySlider.centerYAnchor),
            slider.widthAnchor.constraint(equalTo: sensitivitySlider.widthAnchor),
        ])
        dpiSlider = slider
        
        let display = NSButton(title: MFLocalizedString("pointer-tab.dpi.button", comment: "DPI"), target: self, action: #selector(resetDPI(_:)))
        display.bezelStyle = .regularSquare
        display.setButtonType(.momentaryPushIn)
        display.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(display)
        NSLayoutConstraint.activate([
            display.leadingAnchor.constraint(equalTo: sensitivityDisplay.leadingAnchor),
            display.trailingAnchor.constraint(equalTo: sensitivityDisplay.trailingAnchor),
            display.centerYAnchor.constraint(equalTo: sensitivityDisplay.centerYAnchor),
            display.widthAnchor.constraint(equalTo: sensitivityDisplay.widthAnchor),
            display.heightAnchor.constraint(equalTo: sensitivityDisplay.heightAnchor),
        ])
        dpiDisplay = display
        
        /// Check saved config to decide initial UI mode — no IPC needed
        if let savedDPI = config("Pointer.logitechDPI") as? Int, savedDPI > 0 {
            confirmedDPIMode = true
            setUsesDPIControls(true)
            dpiDisplay.title = "\(savedDPI)"
        } else {
            setUsesDPIControls(false)
        }
    }
    
    private func setupLogitechSettingsUI() {
        let settingsStack = NSStackView()
        settingsStack.orientation = .vertical
        settingsStack.alignment = .leading
        settingsStack.spacing = 7
        settingsStack.translatesAutoresizingMaskIntoConstraints = false
        
        wheelModeControl = NSSegmentedControl(labels: [
            MFLocalizedString("pointer-tab.wheel-mode.ratchet", comment: "Ratchet"),
            MFLocalizedString("pointer-tab.wheel-mode.free", comment: "Free")
        ], trackingMode: .selectOne, target: self, action: #selector(wheelModeChanged(_:)))
        wheelModeControl.segmentStyle = .rounded
        wheelModeControl.translatesAutoresizingMaskIntoConstraints = false
        wheelModeControl.widthAnchor.constraint(equalToConstant: 187).isActive = true
        settingsStack.addArrangedSubview(wheelModeControl)
        
        autoShiftButton = NSButton(checkboxWithTitle: MFLocalizedString("pointer-tab.smartshift", comment: "SmartShift"), target: self, action: #selector(autoShiftChanged(_:)))
        settingsStack.addArrangedSubview(autoShiftButton)
        
        thresholdSlider = NSSlider(value: 20, minValue: 1, maxValue: 50, target: self, action: #selector(thresholdChanged(_:)))
        thresholdSlider.isContinuous = true
        thresholdLabel = NSTextField(labelWithString: "20")
        thresholdRow = makeSliderRow(title: MFLocalizedString("pointer-tab.threshold", comment: "Threshold"), slider: thresholdSlider, valueLabel: thresholdLabel)
        settingsStack.addArrangedSubview(thresholdRow)
        
        torqueSlider = NSSlider(value: 0, minValue: 0, maxValue: 100, target: self, action: #selector(torqueChanged(_:)))
        torqueSlider.isContinuous = true
        torqueLabel = NSTextField(labelWithString: "0")
        torqueRow = makeSliderRow(title: MFLocalizedString("pointer-tab.torque", comment: "Torque"), slider: torqueSlider, valueLabel: torqueLabel)
        settingsStack.addArrangedSubview(torqueRow)
        
        // HiRes Scroll Wheel toggle
        let hiResStack = NSStackView()
        hiResStack.orientation = .horizontal
        hiResStack.alignment = .centerY
        hiResStack.spacing = 8
        
        hiResToggle = NSButton(checkboxWithTitle: MFLocalizedString("pointer-tab.hires-wheel", comment: "HiRes Scroll"), target: self, action: #selector(hiResToggleChanged(_:)))
        hiResStack.addArrangedSubview(hiResToggle)
        hiResRow = hiResStack
        settingsStack.addArrangedSubview(hiResStack)
        hiResRow.isHidden = true
        
        // Report Rate popup
        let rateStack = NSStackView()
        rateStack.orientation = .horizontal
        rateStack.alignment = .centerY
        rateStack.spacing = 8
        
        let rateTitle = NSTextField(labelWithString: MFLocalizedString("pointer-tab.report-rate", comment: "Report Rate:"))
        rateTitle.textColor = .secondaryLabelColor
        rateTitle.font = .systemFont(ofSize: 12)
        rateTitle.translatesAutoresizingMaskIntoConstraints = false
        rateTitle.widthAnchor.constraint(equalToConstant: 80).isActive = true
        
        reportRatePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        reportRatePopup.target = self
        reportRatePopup.action = #selector(reportRateChanged(_:))
        reportRatePopup.translatesAutoresizingMaskIntoConstraints = false
        reportRatePopup.widthAnchor.constraint(equalToConstant: 100).isActive = true
        
        rateStack.addArrangedSubview(rateTitle)
        rateStack.addArrangedSubview(reportRatePopup)
        reportRateRow = rateStack
        settingsStack.addArrangedSubview(rateStack)
        reportRateRow.isHidden = true
        
        logiSettingsStack = settingsStack
        accelerationStack.addArrangedSubview(settingsStack)
        settingsStack.isHidden = true
    }
    
    private func makeSliderRow(title: String, slider: NSSlider, valueLabel: NSTextField) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.widthAnchor.constraint(equalToConstant: 62).isActive = true
        
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 120).isActive = true
        
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        valueLabel.alignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.widthAnchor.constraint(equalToConstant: 34).isActive = true
        
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(slider)
        row.addArrangedSubview(valueLabel)
        return row
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        /// Do NOT call pollLogitechInfo() synchronously here — it blocks the main thread
        /// with IPC calls and can prevent the tab from appearing if the helper is slow/not ready.
        /// Initial UI state is set from saved config in setupDPIControls().
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
        /// Fire first poll after a short delay to avoid blocking tab transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.pollLogitechInfo()
        }
    }
    
    private func stopPolling() {
        queryTimer?.invalidate()
        queryTimer = nil
    }
    
    private func pollLogitechInfo() {
        /// Dispatch all IPC to a background queue to avoid blocking the main thread.
        /// The helper may be slow to respond (especially at startup), and synchronous
        /// IPC here would freeze the entire Mouse tab.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            guard let response = MFMessagePort.sendMessage("queryLogitechInfo", withPayload: nil, waitForReply: true) as? [String: Any] else {
                DispatchQueue.main.async {
                    if !self.confirmedDPIMode {
                        self.updateLogitechUI(isLogitech: false, batteryPercentage: -1, batteryStatus: -1, dpi: -1)
                        self.updateLogitechStateUI(nil)
                    }
                }
                return
            }
            
            let isLogitech = response["isLogitech"] as? Bool ?? false
            let batteryPercentage = response["batteryPercentage"] as? Int ?? -1
            let batteryStatus = response["batteryStatus"] as? Int ?? -1
            let dpi = response["dpi"] as? Int ?? -1
            
            var state: [String: Any]? = nil
            var hiResState: [String: Any]? = nil
            var reportRateState: [String: Any]? = nil
            if isLogitech {
                state = MFMessagePort.sendMessage("getLogitechState", withPayload: nil, waitForReply: true) as? [String: Any]
                hiResState = MFMessagePort.sendMessage("getLogitechHiResState", withPayload: nil, waitForReply: true) as? [String: Any]
                reportRateState = MFMessagePort.sendMessage("getLogitechReportRate", withPayload: nil, waitForReply: true) as? [String: Any]
                if dpi > 0 && !(state?["supportsDPI"] as? Bool ?? false) {
                    state = state ?? [:]
                    state?["supportsDPI"] = true
                    state?["currentDpi"] = dpi
                    state?["minDpi"] = 400
                    state?["maxDpi"] = 4000
                    state?["step"] = 50
                }
                if self.confirmedDPIMode && !(state?["supportsDPI"] as? Bool ?? false) {
                    state = state ?? [:]
                    state?["supportsDPI"] = true
                }
            }
            
            DispatchQueue.main.async {
                self.updateLogitechUI(isLogitech: isLogitech, batteryPercentage: batteryPercentage, batteryStatus: batteryStatus, dpi: dpi)
                if isLogitech {
                    self.updateLogitechStateUI(state)
                    self.updateHiResUI(hiResState)
                    self.updateReportRateUI(reportRateState)
                } else if !self.confirmedDPIMode {
                    self.updateLogitechStateUI(nil)
                    self.updateHiResUI(nil)
                    self.updateReportRateUI(nil)
                }
            }
        }
    }
    
    private func updateLogitechUI(isLogitech: Bool, batteryPercentage: Int, batteryStatus: Int, dpi: Int) {
        /// Use plain isHidden — no CollapsingStackView collapse system
        if !isLogitech {
            /// Don't hide the info stack if we're in confirmed DPI mode
            if !confirmedDPIMode {
                self.logiInfoStack.isHidden = true
            }
            return
        }
        
        self.logiInfoStack.isHidden = false
        
        // Update battery
        if batteryPercentage >= 0 {
            var statusString = ""
            var iconName = "battery.100"
            
            // Map HID++ 2.0 battery status
            if batteryStatus == 1 {
                statusString = MFLocalizedString("pointer-tab.battery.charging", comment: " (Charging)")
                iconName = "battery.100.bolt"
            } else if batteryStatus == 2 {
                statusString = MFLocalizedString("pointer-tab.battery.full", comment: " (Full)")
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
            
            let format = MFLocalizedString("pointer-tab.battery.format", comment: "Battery: %1$d%%%2$@")
            self.batteryLabel.stringValue = String(format: format, batteryPercentage, statusString)
            if #available(macOS 11.0, *) {
                self.batteryIcon.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Battery")
            }
        } else {
            self.batteryLabel.stringValue = MFLocalizedString("pointer-tab.battery.none", comment: "Battery: --")
            if #available(macOS 11.0, *) {
                self.batteryIcon.image = NSImage(systemSymbolName: "battery.100", accessibilityDescription: "Battery")
            }
        }
        
        // Update DPI
        if dpi >= 0 {
            let format = MFLocalizedString("pointer-tab.dpi.format", comment: "DPI: %d")
            self.dpiLabel.stringValue = String(format: format, dpi)
        } else {
            self.dpiLabel.stringValue = MFLocalizedString("pointer-tab.dpi.none", comment: "DPI: --")
        }
    }
    
    private func updateLogitechStateUI(_ state: [String: Any]?) {
        let supportsDPI = state?["supportsDPI"] as? Bool ?? false
        let supportsSmartShift = state?["supportsSmartShift"] as? Bool ?? false
        let supportsTunableTorque = state?["supportsTunableTorque"] as? Bool ?? false
        
        /// Only upgrade to DPI mode, never downgrade once confirmed
        if supportsDPI {
            confirmedDPIMode = true
            setUsesDPIControls(true)
        } else if !confirmedDPIMode {
            setUsesDPIControls(false)
        }
        // else: confirmed DPI mode + transient supportsDPI=false → keep DPI controls
        
        if !confirmedDPIMode {
            logiSettingsStack.isHidden = !supportsSmartShift
        } else if supportsSmartShift {
            logiSettingsStack.isHidden = false
        }
        
        guard let state = state else { return }
        guard Date().timeIntervalSince(lastLogitechUserChange) > 0.5 else { return }
        
        isUpdatingLogitechUI = true
        
        if supportsDPI {
            dpiMin = state["minDpi"] as? Int ?? 0
            dpiMax = state["maxDpi"] as? Int ?? 0
            dpiStep = max(state["step"] as? Int ?? 50, 1)
            let currentDpi = state["currentDpi"] as? Int ?? -1
            if dpiMin > 0 && dpiMax > dpiMin && currentDpi > 0 {
                dpiSlider.minValue = Double(dpiMin)
                dpiSlider.maxValue = Double(dpiMax)
                dpiSlider.doubleValue = Double(currentDpi)
                dpiSlider.numberOfTickMarks = 0
                dpiDisplay.title = "\(currentDpi)"
            }
        }
        
        if supportsSmartShift {
            let autoShift = config("Pointer.logitechAutoShift") as? Int ?? 0
            autoShiftButton.state = autoShift == 0 ? .off : .on
            
            let wheelMode = config("Pointer.logitechWheelMode") as? Int ?? 1
            if autoShift != 0 {
                wheelModeControl.selectedSegment = 0 // 强行设为 Ratchet 分段
                wheelModeControl.isEnabled = false
            } else {
                wheelModeControl.selectedSegment = wheelMode == 0 ? 1 : 0
                wheelModeControl.isEnabled = true
            }
            
            let threshold = state["threshold"] as? Int ?? 20
            thresholdSlider.integerValue = threshold
            thresholdLabel.stringValue = "\(threshold)"
            thresholdRow.isHidden = autoShift == 0
            
            let torque = state["torque"] as? Int ?? 0
            torqueSlider.integerValue = torque
            torqueLabel.stringValue = "\(torque)"
            torqueRow.isHidden = !supportsTunableTorque
        }
        
        isUpdatingLogitechUI = false
    }
    
    private func setUsesDPIControls(_ usesDPI: Bool) {
        sensitivitySlider.isHidden = usesDPI
        sensitivityDisplay.isHidden = usesDPI
        sensitivityLabel?.stringValue = usesDPI ? MFLocalizedString("pointer-tab.dpi.label", comment: "DPI:") : MFLocalizedString("pointer-tab.sensitivity.label", comment: "Sensitivity:")
        sensitivityTickLabels.forEach { $0.isHidden = usesDPI }
        dpiSlider?.isHidden = !usesDPI
        dpiDisplay?.isHidden = !usesDPI
    }
    
    @objc private func dpiSliderChanged(_ sender: NSSlider) {
        guard !isUpdatingLogitechUI else { return }
        let dpi = snappedDPI(Int(sender.doubleValue.rounded()))
        sender.integerValue = dpi
        dpiDisplay.title = "\(dpi)"
        setConfig("Pointer.logitechDPI", NSNumber(value: dpi))
        commitConfig()
        confirmedDPIMode = true
        lastLogitechUserChange = Date()
        _ = MFMessagePort.sendMessage("setLogitechDPI", withPayload: NSNumber(value: dpi), waitForReply: false)
    }
    
    @objc private func resetDPI(_ sender: NSButton) {
        guard dpiMin > 0, dpiMax > dpiMin else { return }
        let fallback = config("Pointer.logitechDPI") as? Int ?? Int(dpiSlider.doubleValue.rounded())
        let dpi = snappedDPI(fallback)
        dpiSlider.integerValue = dpi
        dpiSliderChanged(dpiSlider)
    }
    
    @objc private func wheelModeChanged(_ sender: NSSegmentedControl) {
        sendSmartShiftSettings()
    }
    
    @objc private func autoShiftChanged(_ sender: NSButton) {
        thresholdRow.isHidden = sender.state != .on
        if sender.state == .on {
            wheelModeControl.selectedSegment = 0 // 强行设为 Ratchet 分段
            wheelModeControl.isEnabled = false   // 置灰
        } else {
            wheelModeControl.isEnabled = true    // 恢复
        }
        sendSmartShiftSettings()
    }
    
    @objc private func thresholdChanged(_ sender: NSSlider) {
        thresholdLabel.stringValue = "\(sender.integerValue)"
        scheduleSendSmartShiftSettings()
    }
    
    @objc private func torqueChanged(_ sender: NSSlider) {
        torqueLabel.stringValue = "\(sender.integerValue)"
        scheduleSendSmartShiftSettings()
    }
    
    private func scheduleSendSmartShiftSettings() {
        NSLog("[PointerTab] scheduleSendSmartShiftSettings triggered")
        pendingSmartShiftTimer?.invalidate()
        pendingSmartShiftTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
            self?.sendSmartShiftSettings()
        }
    }
    
    private func sendSmartShiftSettings() {
        guard !isUpdatingLogitechUI else { return }
        let wheelMode = wheelModeControl.selectedSegment == 1 ? 0 : 1
        let autoShift = autoShiftButton.state == .on ? 1 : 0
        let threshold = thresholdSlider.integerValue
        let torque = torqueSlider.integerValue
        
        setConfig("Pointer.logitechWheelMode", NSNumber(value: wheelMode))
        setConfig("Pointer.logitechAutoShift", NSNumber(value: autoShift))
        setConfig("Pointer.logitechSmartShiftThreshold", NSNumber(value: threshold))
        setConfig("Pointer.logitechTorque", NSNumber(value: torque))
        commitConfig()
        
        lastLogitechUserChange = Date()
        let payload: NSDictionary = [
            "wheelMode": wheelMode,
            "autoShift": autoShift,
            "threshold": threshold,
            "torque": torque,
        ]
        _ = MFMessagePort.sendMessage("setLogitechSmartShift", withPayload: payload, waitForReply: false)
    }
    
    private func snappedDPI(_ dpi: Int) -> Int {
        guard dpiStep > 0, dpiMin > 0 else { return dpi }
        let clamped = min(max(dpi, dpiMin), dpiMax)
        let steps = Double(clamped - dpiMin) / Double(dpiStep)
        return dpiMin + Int(steps.rounded()) * dpiStep
    }
    
    // MARK: - HiRes Scroll Wheel
    
    private func updateHiResUI(_ state: [String: Any]?) {
        let supported = state?["supported"] as? Bool ?? false
        
        if supported {
            confirmedHiResSupport = true
        }
        
        hiResRow.isHidden = !confirmedHiResSupport
        
        guard let state = state, supported else { return }
        guard Date().timeIntervalSince(lastLogitechUserChange) > 0.5 else { return }
        
        isUpdatingLogitechUI = true
        let enabled = state["hiResEnabled"] as? Bool ?? false
        hiResToggle.state = enabled ? .on : .off
        
        if let multiplier = state["multiplier"] as? Int, multiplier > 0 {
            hiResToggle.title = MFLocalizedString("pointer-tab.hires-wheel", comment: "HiRes Scroll") + " (\(multiplier)x)"
        }
        isUpdatingLogitechUI = false
    }
    
    @objc private func hiResToggleChanged(_ sender: NSButton) {
        guard !isUpdatingLogitechUI else { return }
        let enabled = sender.state == .on
        setConfig("Pointer.logitechHiResWheel", NSNumber(value: enabled))
        commitConfig()
        lastLogitechUserChange = Date()
        _ = MFMessagePort.sendMessage("setLogitechHiResMode", withPayload: NSNumber(value: enabled), waitForReply: false)
    }
    
    // MARK: - Report Rate
    
    private func updateReportRateUI(_ state: [String: Any]?) {
        let supported = state?["supported"] as? Bool ?? false
        
        if supported {
            confirmedReportRateSupport = true
        }
        
        reportRateRow.isHidden = !confirmedReportRateSupport
        
        guard let state = state, supported else { return }
        guard Date().timeIntervalSince(lastLogitechUserChange) > 0.5 else { return }
        
        isUpdatingLogitechUI = true
        
        // Populate available rates
        let rates = state["rates"] as? [Int] ?? []
        let currentRate = state["currentRate"] as? Int ?? 0
        let currentRateHz = state["currentRateHz"] as? Int ?? 0
        
        reportRatePopup.removeAllItems()
        reportRateIndexMap.removeAll()
        
        // Rate index → Hz mapping
        let rateMapping: [(UInt8, Int)] = [(1, 125), (2, 250), (3, 500), (4, 1000), (5, 2000), (6, 4000), (8, 8000)]
        
        var selectedIndex = 0
        for (popupIdx, hz) in rates.enumerated() {
            reportRatePopup.addItem(withTitle: "\(hz) Hz")
            // Find the rate index for this Hz value
            if let mapping = rateMapping.first(where: { Int($0.1) == hz }) {
                reportRateIndexMap[popupIdx] = mapping.0
                if Int(mapping.0) == currentRate || hz == currentRateHz {
                    selectedIndex = popupIdx
                }
            }
        }
        
        if reportRatePopup.numberOfItems > 0 {
            reportRatePopup.selectItem(at: selectedIndex)
        }
        
        isUpdatingLogitechUI = false
    }
    
    @objc private func reportRateChanged(_ sender: NSPopUpButton) {
        guard !isUpdatingLogitechUI else { return }
        let selectedIdx = sender.indexOfSelectedItem
        guard let rateIndex = reportRateIndexMap[selectedIdx] else { return }
        
        setConfig("Pointer.logitechReportRate", NSNumber(value: rateIndex))
        commitConfig()
        lastLogitechUserChange = Date()
        _ = MFMessagePort.sendMessage("setLogitechReportRate", withPayload: NSNumber(value: rateIndex), waitForReply: false)
    }
}
