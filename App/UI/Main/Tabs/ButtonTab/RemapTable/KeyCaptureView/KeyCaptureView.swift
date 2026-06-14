//
// --------------------------------------------------------------------------
// KeyCaptureView.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Cocoa
import Carbon

public typealias CaptureHandler = (CGKeyCode, UInt32, CGEventFlags) -> Void
public typealias CancelHandler = () -> Void

@objc(KeyCaptureView)
public class KeyCaptureView: NSTextView, NSTextViewDelegate {
    
    private var _isCapturing: Bool = false
    private var _captureHandler: CaptureHandler?
    private var _cancelHandler: CancelHandler?
    private var _localEventMonitor: Any?
    private var _attributesFromIB: [NSAttributedString.Key: Any]?
    private var _windowResignObserver: Any?
    
    public override var acceptsFirstResponder: Bool {
        return true
    }
    
    @objc public func setCoolString(_ string: String) {
        let attrs = _attributesFromIB ?? [:]
        let attributedString = NSAttributedString(string: string, attributes: attrs)
        self.textStorage?.setAttributedString(attributedString)
    }
    
    @objc public func setup(withCaptureHandler captureHandler: @escaping CaptureHandler,
                             cancelHandler: @escaping CancelHandler) {
        DDLogDebug("Setting up keystroke capture view")
        self.delegate = self
        self._captureHandler = captureHandler
        self._cancelHandler = cancelHandler
        
        DispatchQueue.main.async {
            MainAppState.shared.window?.makeFirstResponder(self)
        }
    }
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        if _attributesFromIB == nil {
            let attrString = self.attributedString()
            if attrString.length > 0 {
                _attributesFromIB = attrString.attributes(at: 0, effectiveRange: nil)
            }
        }
    }
    
    public func drawEmptyAppearance() {
        self.setCoolString(MFLocalizedString("type-shortcut-prompt", comment: ""))
        self.textColor = .placeholderTextColor
        self.selectAll(nil)
    }
    
    @objc public static func handleKeyCaptureModeFeedback(withPayload payload: [AnyHashable: Any], isSystemDefinedEvent isSystem: Bool) {
        guard let remapsTable = MainAppState.shared.remapTable else { return }
        let effectColumn = remapsTable.column(withIdentifier: NSUserInterfaceItemIdentifier("effect"))
        if effectColumn == -1 { return }
        let indexes = NSMutableIndexSet()
        for r in 0..<remapsTable.numberOfRows {
            if let effectView = remapsTable.view(atColumn: effectColumn, row: r, makeIfNecessary: false),
               effectView.identifier == NSUserInterfaceItemIdentifier("keyCaptureCell") {
                indexes.add(r)
            }
        }
        assert(indexes.count <= 1)
        if indexes.count == 0 { return }
        
        if let keyCaptureCell = remapsTable.view(atColumn: effectColumn, row: indexes.firstIndex, makeIfNecessary: false) {
            let subviews = keyCaptureCell.nestedSubviews(withIdentifier: NSUserInterfaceItemIdentifier("keyCaptureView"))
            if let keyCaptureView = subviews.first as? KeyCaptureView {
                keyCaptureView.handleKeyCaptureModeFeedback(withPayload: payload, isSystemDefinedEvent: isSystem)
            }
        }
    }
    
    @objc public func handleKeyCaptureModeFeedback(withPayload payload: [AnyHashable: Any], isSystemDefinedEvent isSystem: Bool) {
        _isCapturing = false
        
        var keyCode: CGKeyCode = CGKeyCode(UInt16.max)
        var type: UInt32 = UInt32(UInt32.max)
        var flags: CGEventFlags = []
        
        if isSystem {
            if let typeNum = payload["systemEventType"] as? NSNumber {
                type = typeNum.uint32Value
            }
            if let flagsNum = payload["flags"] as? NSNumber {
                flags = CGEventFlags(rawValue: flagsNum.uint64Value)
            }
        } else {
            if let codeNum = payload["keyCode"] as? NSNumber {
                keyCode = codeNum.uint16Value
            }
            if let flagsNum = payload["flags"] as? NSNumber {
                flags = CGEventFlags(rawValue: flagsNum.uint64Value)
            }
        }
        
        MainAppState.shared.window?.makeFirstResponder(nil)
        _captureHandler?(keyCode, type, flags)
    }
    
    public override func becomeFirstResponder() -> Bool {
        DDLogDebug("BECOME FIRST RESPONDER")
        let superAccepts = super.becomeFirstResponder()
        DDLogDebug("superAccepts: \(superAccepts)")
        
        _isCapturing = true
        
        if _windowResignObserver == nil {
            _windowResignObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: MainAppState.shared.window,
                queue: nil) { [weak self] _ in
                    MainAppState.shared.window?.makeFirstResponder(nil)
                }
        }
        
        _ = MFMessagePort.sendMessage("enableKeyCaptureMode", withPayload: "" as NSObject, waitForReply: false)
        self.drawEmptyAppearance()
        
        if _localEventMonitor == nil {
            _localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown, .leftMouseDown]) { [weak self] event in
                guard let self = self else { return event }
                guard let e = event.cgEvent else { return event }
                
                if event.type == .flagsChanged {
                    let flags = e.flags
                    let modString = UIStrings.getKeyboardModifierString(flags)
                    if modString.count > 0 {
                        self.setCoolString(modString)
                    } else {
                        self.drawEmptyAppearance()
                    }
                } else if event.type == .keyDown {
                    // Ignore
                } else if event.type == .leftMouseDown {
                    MainAppState.shared.window?.makeFirstResponder(nil)
                }
                
                return nil
            }
        }
        
        return true
    }
    
    public override func resignFirstResponder() -> Bool {
        DDLogDebug("RESIGN FIRST RESPONDER")
        let superResigns = super.resignFirstResponder()
        DDLogDebug("superResigns: \(superResigns)")
        
        _ = MFMessagePort.sendMessage("disableKeyCaptureMode", withPayload: nil, waitForReply: false)
        if let monitor = _localEventMonitor {
            NSEvent.removeMonitor(monitor)
            _localEventMonitor = nil
        }
        if let obs = _windowResignObserver {
            NotificationCenter.default.removeObserver(obs)
            _windowResignObserver = nil
        }
        _cancelHandler?()
        return true
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        if let obs = _windowResignObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        if let monitor = _localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    public override func mouseDown(with event: NSEvent) {
        // Ignore
    }
    
    public override func mouseMoved(with event: NSEvent) {
        NSCursor.arrow.set()
    }
    
    public override func scrollWheel(with event: NSEvent) {
        NSCursor.arrow.set()
    }
    
    @IBAction func backgroundButton(_ sender: Any) {
        // Ignore
    }
}
