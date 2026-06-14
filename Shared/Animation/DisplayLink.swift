//
// --------------------------------------------------------------------------
// DisplayLink.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation
import Cocoa
import CoreVideo
import os.log

@objc(DisplayLink)
public class DisplayLink: NSObject {
    
    fileprivate enum RequestedState {
        case stopped
        case running
    }
    
    private var _displayLink: CVDisplayLink?
    private var _previousDisplayUnderMousePointer: CGDirectDisplayID = 0
    fileprivate var _displayLinkIsOutdated: Bool = false
    private let _displayLinkQueue: DispatchQueue
    fileprivate var _requestedState: RequestedState = .stopped
    private var _optimizedWorkType: MFDisplayLinkWorkType
    private var _startGeneration: UInt64 = 0
    
    @objc public var callback: DisplayLinkCallback?
    
    @objc public var dispatchQueue: DispatchQueue {
        return _displayLinkQueue
    }
    
    @objc(displayLinkOptimizedForWorkType:)
    public static func displayLinkOptimizedForWorkType(_ workType: MFDisplayLinkWorkType) -> DisplayLink {
        return DisplayLink(optimizedFor: workType)
    }
    
    @objc(initOptimizedForWorkType:)
    public init(optimizedFor workType: MFDisplayLinkWorkType) {
        self._optimizedWorkType = workType
        
        self._displayLinkQueue = DispatchQueue(label: "com.nuebling.mac-mouse-fix.helper.display-link", qos: .userInteractive)
        
        super.init()
        
        self.setUpNewDisplayLinkWithActiveDisplays()
        self._displayLinkIsOutdated = false
        self._requestedState = .stopped
        self._startGeneration = 0
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        CGDisplayRegisterReconfigurationCallback(displayReconfigurationCallback, selfPtr)
    }
    
    deinit {
        if let dl = _displayLink {
            CVDisplayLinkStop(dl)
        }
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        CGDisplayRemoveReconfigurationCallback(displayReconfigurationCallback, selfPtr)
    }
    
    private func setUpNewDisplayLinkWithActiveDisplays() {
        DDLogDebug("DisplayLink.swift: (\(self.identifier)) Running -[setUpNewDisplayLinkWithActiveDisplays] on thread \(Thread.current)")
        
        if let oldDL = _displayLink {
            let ret = CVDisplayLinkStop(oldDL)
            assert(ret == kCVReturnDisplayLinkNotRunning)
            DDLogDebug("DisplayLink.swift: (\(self.identifier)) Deleting existing CVDisplayLink. StopCode: \(ret)")
            _displayLink = nil
        }
        
        let maxTries = 20
        var ret: CVReturn = -1
        var ret2: CVReturn = -1
        
        for i in 0..<maxTries {
            var dl: CVDisplayLink?
            ret = CVDisplayLinkCreateWithActiveCGDisplays(&dl)
            if ret == kCVReturnSuccess, let validDL = dl {
                let selfPtr = Unmanaged.passUnretained(self).toOpaque()
                ret2 = CVDisplayLinkSetOutputCallback(validDL, displayLinkCallback, selfPtr)
                if ret2 == kCVReturnSuccess {
                    _displayLink = validDL
                    DDLogDebug("DisplayLink.swift: (\(self.identifier)) Created CVDisplayLink (\(validDL)) on try \(i)")
                    return
                }
            }
        }
        
        DDLogError("DisplayLink.swift: (\(self.identifier)) Failed to create CVDisplayLink after \(maxTries) tries. Last codes: (\(ret), \(ret2))")
        _displayLink = nil
    }
    
    @objc(startWithCallback:)
    public func start(callback: @escaping DisplayLinkCallback) {
        _displayLinkQueue.async {
            self.start_Unsafe(callback: callback)
        }
    }
    
    @objc(start_UnsafeWithCallback:)
    public func start_Unsafe(callback: @escaping DisplayLinkCallback) {
        DDLogDebug("DisplayLink.swift: (\(self.identifier)) starting")
        self.callback = callback
        
        _startGeneration += 1
        let startGeneration = _startGeneration
        
        _requestedState = .running
        
        let startDisplayLinkBlock = { [weak self] in
            guard let self = self else { return }
            var failedAttempts: Int64 = 0
            let maxAttempts: Int64 = 100
            var rt: CVReturn = kCVReturnSuccess
            
            while true {
                guard let dl = self._displayLink else {
                    rt = kCVReturnError
                    break
                }
                rt = CVDisplayLinkStart(dl)
                if rt == kCVReturnSuccess || rt == kCVReturnDisplayLinkAlreadyRunning {
                    break
                }
                
                failedAttempts += 1
                if failedAttempts >= maxAttempts {
                    DDLogWarn("DisplayLink.swift: (\(self.identifier)) Failed to start CVDisplayLink after \(failedAttempts) tries. Last error code: \(rt). Rebuilding displayLink and marking stopped.")
                    self._displayLinkQueue.async {
                        if self._requestedState == .running && self._startGeneration == startGeneration {
                            self._requestedState = .stopped
                            self.setUpNewDisplayLinkWithActiveDisplays()
                        }
                    }
                    break
                }
            }
        }
        
        DispatchQueue.main.async(execute: startDisplayLinkBlock)
    }
    
    @objc(stop)
    public func stop() {
        _displayLinkQueue.async {
            self.stop_Unsafe()
        }
    }
    
    @objc(stop_Unsafe)
    public func stop_Unsafe() {
        DDLogDebug("DisplayLink.swift: (\(self.identifier)) stopping")
        if self.isRunning_Unsafe() {
            _requestedState = .stopped
            _startGeneration += 1
            
            let workload = { [weak self] in
                guard let self = self else { return }
                if let dl = self._displayLink {
                    CVDisplayLinkStop(dl)
                }
            }
            
            DispatchQueue.main.async(execute: workload)
        }
    }
    
    @objc(isRunning)
    public func isRunning() -> Bool {
        var result = false
        _displayLinkQueue.sync {
            result = self.isRunning_Unsafe()
        }
        return result
    }
    
    @objc(isRunning_Unsafe)
    public func isRunning_Unsafe() -> Bool {
        return _requestedState == .running
    }
    
    @objc public static func callerIsRunningOnDisplayLinkThread() -> Bool {
        return Thread.current.name == "CVDisplayLink"
    }
    
    public static func identifierForDisplayLink(_ dl: CVDisplayLink?) -> String {
        guard let dl = dl else { return "nil" }
        let pointerNumber = Int(bitPattern: Unmanaged.passUnretained(dl).toOpaque())
        return "\(pointerNumber)"
    }
    
    public var identifier: String {
        return DisplayLink.identifierForDisplayLink(_displayLink)
    }
    
    @objc(bestTimeBetweenFramesEstimate)
    public func bestTimeBetweenFramesEstimate() -> CFTimeInterval {
        guard let dl = _displayLink else {
            return 1.0 / 60.0
        }
        var t = CVDisplayLinkGetActualOutputVideoRefreshPeriod(dl)
        if t == 0 {
            let tCV = CVDisplayLinkGetNominalOutputVideoRefreshPeriod(dl)
            if tCV.timeScale != 0 {
                t = Double(tCV.timeValue) / Double(tCV.timeScale)
            } else {
                t = 1.0 / 60.0
            }
        }
        return t
    }
    
    @objc(timeBetweenFrames)
    public func timeBetweenFrames() -> CFTimeInterval {
        guard let dl = _displayLink else {
            return 1.0 / 60.0
        }
        return CVDisplayLinkGetActualOutputVideoRefreshPeriod(dl)
    }
    
    @objc(nominalTimeBetweenFrames)
    public func nominalTimeBetweenFrames() -> CFTimeInterval {
        guard let dl = _displayLink else {
            return 1.0 / 60.0
        }
        let t = CVDisplayLinkGetNominalOutputVideoRefreshPeriod(dl)
        if t.timeScale != 0 {
            return Double(t.timeValue) / Double(t.timeScale)
        }
        return 1.0 / 60.0
    }
    
    @objc(linkToMainScreen)
    public func linkToMainScreen() {
        _displayLinkQueue.async {
            self.linkToMainScreen_Unsafe()
        }
    }
    
    @objc(linkToMainScreen_Unsafe)
    public func linkToMainScreen_Unsafe() {
        if let mainScreen = NSScreen.main {
            _ = self.setDisplay(mainScreen.displayID())
        }
    }
    
    @objc(linkToDisplayUnderMousePointerWithEvent:)
    public func linkToDisplayUnderMousePointer(event: CGEvent?) {
        #if IS_HELPER
        _displayLinkQueue.async { [weak self] in
            guard let self = self else { return }
            var dsp: CGDirectDisplayID = 0
            let rt = HelperUtility.displayUnderMousePointer(&dsp, with: event)
            if rt == kCVReturnError {
                return
            }
            if dsp == self._previousDisplayUnderMousePointer {
                return
            }
            self._previousDisplayUnderMousePointer = dsp
            _ = self.setDisplay(dsp)
        }
        #else
        assertionFailure("linkToDisplayUnderMousePointerWithEvent is helper only")
        #endif
    }
    
    private func setDisplay(_ displayID: CGDirectDisplayID) -> CVReturn {
        if _displayLinkIsOutdated {
            setUpNewDisplayLinkWithActiveDisplays()
            _displayLinkIsOutdated = false
        }
        
        guard let dl = _displayLink else {
            return kCVReturnError
        }
        
        let ret = CVDisplayLinkSetCurrentCGDisplay(dl, displayID)
        DDLogDebug("DisplayLink.swift: (\(self.identifier)) set to display \(displayID). Error: \(ret)")
        if ret != kCVReturnSuccess {
            DDLogError("DisplayLink.swift: (\(self.identifier)) Failed to set display \(displayID), error: \(ret)")
            return ret
        }
        return kCVReturnSuccess
    }
}

// MARK: - Callbacks

private let displayLinkCallback: CVDisplayLinkOutputCallback = { displayLink, inNow, inOutputTime, flagsIn, flagsOut, displayLinkContext in
    guard let context = displayLinkContext else {
        return kCVReturnSuccess
    }
    let selfInstance = Unmanaged<DisplayLink>.fromOpaque(context).takeUnretainedValue()
    
    selfInstance.dispatchQueue.sync {
        DDLogDebug("DisplayLink.swift: (\(selfInstance.identifier)) Callback")
        
        let timeInfo = parseTimeStamps(inNow: inNow, inOutputTime: inOutputTime)
        
        if selfInstance._requestedState == .stopped {
            DDLogDebug("DisplayLink.swift: (\(selfInstance.identifier)) callback called after requested stop. Returning")
            return
        }
        
        if let callback = selfInstance.callback {
            callback(timeInfo)
        }
    }
    
    return kCVReturnSuccess
}

private let displayReconfigurationCallback: CGDisplayReconfigurationCallBack = { display, flags, userInfo in
    guard let context = userInfo else { return }
    let selfInstance = Unmanaged<DisplayLink>.fromOpaque(context).takeUnretainedValue()
    
    if flags.contains(.addFlag) || flags.contains(.removeFlag) || flags.contains(.enabledFlag) || flags.contains(.disabledFlag) {
        DDLogInfo("DisplayLink.swift: (\(selfInstance.identifier)) added / removed. Flagging the displayLink as outdated. display: \(display), flags: \(flags)")
        selfInstance._displayLinkIsOutdated = true
    } else {
        DDLogDebug("DisplayLink.swift: (\(selfInstance.identifier)) Ignored display reconfiguration. display: \(display), flags: \(flags)")
    }
}

// MARK: - Timestamps Helper

private struct ParsedCVTimeStamp {
    var hostTS: CFTimeInterval
    var frameTS: CFTimeInterval
    var period: CFTimeInterval
    var nominalPeriod: CFTimeInterval
}

private func parseTimeStamp(ts: UnsafePointer<CVTimeStamp>) -> ParsedCVTimeStamp {
    let f = CVTimeStampFlags(rawValue: ts.pointee.flags)
    
    let hostTimeIsValid = f.contains(.videoHostTimeValid)
    let interlaced = f.contains(.isInterlaced)
    let SMPTETimeIsValid = f.contains(.smpteTimeValid)
    let videoRefreshPeriodIsValid = f.contains(.videoRefreshPeriodValid)
    let timeStampRateScalerIsValid = f.contains(.rateScalarValid)
    
    if !hostTimeIsValid || interlaced || SMPTETimeIsValid || !videoRefreshPeriodIsValid || !timeStampRateScalerIsValid {
        DDLogWarn("DisplayLink.swift: CVTimeStamp flags are weird - hostTimeIsValid: \(hostTimeIsValid), interlaced: \(interlaced), SMPTE: \(SMPTETimeIsValid), refreshPeriod: \(videoRefreshPeriodIsValid), rateScaler: \(timeStampRateScalerIsValid)")
    }
    
    let videoTimeScale = ts.pointee.videoTimeScale
    let videoTime = ts.pointee.videoTime
    let videoRefreshPeriod = ts.pointee.videoRefreshPeriod
    let hostTime = ts.pointee.hostTime
    let rateScalar = ts.pointee.rateScalar
    
    let tsVideo = Double(videoTime) / Double(videoTimeScale)
    let hostTimeScaled = machTimeToSeconds(hostTime)
    
    let periodVideoNominal = Double(videoRefreshPeriod) / Double(videoTimeScale)
    let periodVideo = periodVideoNominal * rateScalar
    
    return ParsedCVTimeStamp(
        hostTS: hostTimeScaled,
        frameTS: tsVideo,
        period: periodVideo,
        nominalPeriod: periodVideoNominal
    )
}

private func parseTimeStamps(inNow: UnsafePointer<CVTimeStamp>, inOutputTime: UnsafePointer<CVTimeStamp>) -> DisplayLinkCallbackTimeInfo {
    let tsNow = parseTimeStamp(ts: inNow)
    let tsOut = parseTimeStamp(ts: inOutputTime)
    
    return DisplayLinkCallbackTimeInfo(
        cvCallbackTime: tsNow.hostTS,
        lastFrame: tsNow.frameTS,
        thisFrame: tsNow.frameTS + tsOut.nominalPeriod,
        outFrame: tsOut.frameTS,
        timeBetweenFrames: tsOut.period,
        nominalTimeBetweenFrames: tsOut.nominalPeriod
    )
}
