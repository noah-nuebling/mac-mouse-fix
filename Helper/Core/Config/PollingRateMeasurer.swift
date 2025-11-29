//
// --------------------------------------------------------------------------
// PollingRateMeasurer.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Too lazy to explain my thinking behind this in detail but it works. Basically round the time deltas between events to 1/8 of a ms because that's the fastest polling rate on the market. Then create histogram and choose most often occuring bucket. Convert to polling rate in Hz and round to increments of 5, because that/s the most fine grained description of polling rate Hz I could find.
///
/// This is horrible code.
///     - Should/ve not written this in Swift. Made it so much harder to deal with C APIs.
///     - Should've made the class vars that the callback needs to access fileprivate globals instead. Would've cleaned things up a lot.
///     - Using magic numbers everywhere, no comments, no whitespace, slightly hacky.

import Foundation

/// Constants
fileprivate let _periodMax = 50.0 /// Max ms between events that we could still consider a polling rate  (50 ms -> 20 Hz)

@objc class PollingRateMeasurer: NSObject {
    
    /// State
    var _lastMeasurementTime: UInt64 = 0
    var _periodHistogram: [Int] = []
    var _measurementCount = 0
    
    /// Event tap
    var _eventTap: CFMachPort? = nil
    var _tapEnabled: Bool = false /// The tap will randombly reactivate and send weird events that don't have a sender, use this to ignore.
    
    /// Store args for access by callback
    var _device: Device? = nil
    var _nSamples: Int = 0
    var _completionCallback: ((Double, Int) -> ())? = nil
    var _progressCallback: ((Double, Double, Int) -> ())? = nil
    
    /// Interface
    
//    @objc func stopMeasuring() {
//
//    }
    
    @objc func measure(onDevice device: Device, numberOfSamples nSamples: Int, completionCallback: @escaping (Double, Int) -> (), progressCallback: @escaping (Double, Double, Int) -> ()) {
        /// Measures the polling rate on `device` by intercepting `nSamples` events from the device and applying a heuristic algorithm I made up.
        /// It will call `progressCallback` with values between 0.0 and 1.0 as more samples come in as its first arg. Second 2 args are like `completionCallback`
        /// Once measurement is completed, it will call `completionCallback` with the `pollingInterval` and the `pollingRate`. `pollingInterval` is given in ms and rounded to 1/8 of a ms. `pollingRate` is given in Hz and rounded to increments of 5.
        
        /// Debug
//        Unmanaged.passRetained(self)
        
        /// Store args
        _device = device
        _nSamples = nSamples
        _completionCallback = completionCallback
        _progressCallback = progressCallback
        
        /// Init state
        _lastMeasurementTime = 0
        _periodHistogram = Array(repeating: 0, count: Int(_periodMax*8.0)+1)
        _measurementCount = 0
        
        /// Create eventTap
        if _eventTap == nil {
        
            /// Setup eventTapCallback
            let eventMask = 1 << CGEventType.mouseMoved.rawValue // | 1 << CGEventType.leftMouseDragged.rawValue | 1 << CGEventType.rightMouseDragged.rawValue | 1 << CGEventType.otherMouseDragged.rawValue
            
            _eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .defaultTap, eventsOfInterest: CGEventMask(eventMask), callback: eventTapCallback, userInfo: Unmanaged.passUnretained(self).toOpaque()) /// Using a listenonly tap totally messes up the timestamps.
            
            let runLoopSource = CFMachPortCreateRunLoopSource(CFAllocatorGetDefault().takeRetainedValue(), _eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, CFRunLoopMode.defaultMode)
        } /// End `if _eventTap == nil`
        
        /// Enable event tap
        CGEvent.tapEnable(tap: _eventTap!, enable: true)
        _tapEnabled = true
    }
}

func eventTapCallback(_ proxy: OpaquePointer, _ type: CGEventType, _ event: CGEvent, _ context: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    
    /// Guard weird events
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        
        if type == .tapDisabledByTimeout {
            CGEvent.tapEnable(tap: _eventTap, enable: true)
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    /// Get self
    let context = context!
    let unmanagedContext = Unmanaged<PollingRateMeasurer>.fromOpaque(context)
    let selfff = unmanagedContext.takeUnretainedValue()
    
    let enabled = selfff._tapEnabled /// This returns true even thought the value is false ????
    if !enabled {
        DDLogInfo("PollingRateMeasurement eventTap called after disabling")
        CGEvent.tapEnable(tap: selfff._eventTap!, enable: false)
        selfff._tapEnabled = false
        return Unmanaged.passUnretained(event)
    }
    
    /// Main Logic
//    let hidEvent = CGEventGetHIDEvent(event)
//    let sender = HIDEventGetSendingDevice(hidEvent)?.takeUnretainedValue()
    let sender = CGEventGetSendingDevice(event)?.takeUnretainedValue();
    guard let sender = sender else { return Unmanaged.passUnretained(event) }
    let senderDeviceID = IOHIDDeviceGetProperty(sender, kIOHIDLocationIDKey as CFString) as! NSNumber /// Not sure if this is good way of comparing devices.
    let targetDeviceID = IOHIDDeviceGetProperty(selfff._device!.iohidDevice, kIOHIDLocationIDKey as CFString) as! NSNumber
    if !senderDeviceID.isEqual(to: targetDeviceID) { return Unmanaged.passUnretained(event) }
    let time = event.timestamp
    let delta: CFTimeInterval = Double(time - selfff._lastMeasurementTime)/Double(NSEC_PER_SEC)
    /// ^ Discussion: normally, CGEvent timestamp is a `mach_absolute_time()` timestamp, and we use CGEventGetTimeStampInSeconds() or related functions to convert to seconds. But here, the CGEvent timestampts are already in nanoseconds! No idea why.
    selfff._lastMeasurementTime = time
    let period = round(delta*1000*8)/8
    if 0 < period && period <= _periodMax {
        selfff._measurementCount += 1
        selfff._periodHistogram[Int(period*8)] += 1
        let doCallProgress = selfff._measurementCount % 5 == 0
        let doCallCompletion = selfff._measurementCount >= selfff._nSamples
        if doCallProgress || doCallCompletion {
            let progress = Double(selfff._measurementCount)/Double(selfff._nSamples)
            let period = Double(selfff._periodHistogram.firstIndex(of: selfff._periodHistogram.max()!)!)/8.0
            let rate = Int(5*round((1000.0/period)/5))
            if doCallProgress {
                selfff._progressCallback!(progress, period, rate)
            }
            if doCallCompletion {
                selfff._completionCallback!(period, rate)
                CGEvent.tapEnable(tap: selfff._eventTap!, enable: false)
                selfff._tapEnabled = false
            }
        }
    }
    
    return Unmanaged.passUnretained(event)
}
