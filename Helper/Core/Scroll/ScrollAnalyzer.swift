//
// --------------------------------------------------------------------------
// ScrollAnalyzer.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#if IS_HELPER

import Cocoa

struct ScrollAnalysisResult {
    var consecutiveScrollTickCounter: Int64
    var consecutiveScrollSwipeCounter: Double
    var scrollDirectionDidChange: Bool
    var timeBetweenTicks: CFTimeInterval
    var DEBUG_timeBetweenTicksRaw: CFTimeInterval
    var DEBUG_consecutiveScrollSwipeCounterRaw: Int64
}

@objc(ScrollAnalyzer)
class ScrollAnalyzer: NSObject {
    
    private static let _tickTimeSmoother: RollingAverage = RollingAverage(capacity: 3)
    
    private static var _previousScrollTickTimeStamp: Double = 0
    private static var _previousDirection: MFDirection = kMFDirectionNone
    
    private static var _consecutiveScrollTickCounter: Int32 = 0
    private static var _consecutiveScrollSwipeCounter: Int32 = 0
    private static var _consecutiveScrollSwipeCounter_ForFreeScrollWheel: Double = 0
    
    private static var _ticksInCurrentConsecutiveSwipeSequence: Int32 = 0
    private static var _consecutiveSwipeSequenceStartTime: CFTimeInterval = -1
    
    @objc static func resetState() {
        _previousScrollTickTimeStamp = 0
        _previousDirection = kMFDirectionNone
        _consecutiveScrollTickCounter = 0
        _consecutiveScrollSwipeCounter = 0
        _consecutiveScrollSwipeCounter_ForFreeScrollWheel = 0
        _ticksInCurrentConsecutiveSwipeSequence = 0
        _consecutiveSwipeSequenceStartTime = -1
    }
    
    private static func directionChanged(_ direction1: MFDirection, _ direction2: MFDirection) -> Bool {
        if direction1 == kMFDirectionNone || direction2 == kMFDirectionNone {
            return false
        }
        return direction1 != direction2
    }
    
    @objc static func peekIsFirstConsecutiveTick(withTickOccuringAt thisScrollTickTimeStamp: CFTimeInterval,
                                                       direction: MFDirection,
                                                       config: ScrollConfig) -> Bool {
        if directionChanged(_previousDirection, direction) {
            return true
        }
        let secondsSinceLastTick = thisScrollTickTimeStamp - _previousScrollTickTimeStamp
        let didTimeOut = secondsSinceLastTick > config.consecutiveScrollTickIntervalMax
        return didTimeOut
    }
    
    static func update(withTickOccuringAt thisScrollTickTimeStamp: CFTimeInterval,
                              direction: MFDirection,
                              config: ScrollConfig) -> ScrollAnalysisResult {
        
        let scrollDirectionDidChange = directionChanged(_previousDirection, direction)
        _previousDirection = direction
        
        if scrollDirectionDidChange {
            resetState()
        }
        
        var secondsSinceLastTick = thisScrollTickTimeStamp - _previousScrollTickTimeStamp
        
        if secondsSinceLastTick < config.consecutiveScrollTickIntervalMin {
            secondsSinceLastTick = config.consecutiveScrollTickIntervalMin
        }
        
        _ticksInCurrentConsecutiveSwipeSequence += 1
        
        if secondsSinceLastTick > config.consecutiveScrollTickIntervalMax {
            
            // --- Update swipes ---
            
            if config.scrollSwipeThreshold_inTicks > _consecutiveScrollTickCounter {
                resetSwipes()
            } else {
                let thisScrollSwipeTimeStamp = thisScrollTickTimeStamp
                let interval = thisScrollSwipeTimeStamp - _previousScrollTickTimeStamp
                
                if interval > config.consecutiveScrollSwipeMaxInterval {
                    resetSwipes()
                } else {
                    let duration = CACurrentMediaTime() - _consecutiveSwipeSequenceStartTime
                    let tickSpeedThisSwipeSequence = duration > 0 ? Double(_ticksInCurrentConsecutiveSwipeSequence) / duration : 0.0
                    
                    if tickSpeedThisSwipeSequence < config.consecutiveScrollSwipeMinTickSpeed {
                        resetSwipes()
                    } else {
                        _consecutiveScrollSwipeCounter += 1
                        _consecutiveScrollSwipeCounter_ForFreeScrollWheel += 1
                        updateTicks()
                    }
                }
            }
            
        } else {
            // This is not the first consecutive tick
            _consecutiveScrollTickCounter += 1
        }
        
        // --- Free scroll wheel counters ---
        // Mechanism is currently disabled in original source code (HOTFIX: Turning this whole mechanism off)
        /*
        if false {
            if _consecutiveScrollTickCounter >= config.scrollSwipeMax_inTicks {
                _consecutiveScrollSwipeCounter_ForFreeScrollWheel += 1.0 / Double(config.scrollSwipeMax_inTicks)
            }
        }
        */
        
        // Smoothing
        var smoothedTimeBetweenTicks: Double = 0
        
        if _consecutiveScrollTickCounter == 0 {
            smoothedTimeBetweenTicks = Double.greatestFiniteMagnitude // DBL_MAX
            _tickTimeSmoother.reset()
            if config.u_smoothness == kMFScrollSmoothnessHigh && !config.u_precise {
                // HORRIBLE HACK
                _ = _tickTimeSmoother.smooth(value: config.consecutiveScrollTickIntervalMax)
            }
        } else {
            assert(secondsSinceLastTick <= config.consecutiveScrollTickIntervalMax)
            smoothedTimeBetweenTicks = _tickTimeSmoother.smooth(value: secondsSinceLastTick)
        }
        
        _previousScrollTickTimeStamp = thisScrollTickTimeStamp
        
        var result = ScrollAnalysisResult(
            consecutiveScrollTickCounter: Int64(_consecutiveScrollTickCounter),
            consecutiveScrollSwipeCounter: _consecutiveScrollSwipeCounter_ForFreeScrollWheel,
            scrollDirectionDidChange: scrollDirectionDidChange,
            timeBetweenTicks: smoothedTimeBetweenTicks,
            DEBUG_timeBetweenTicksRaw: secondsSinceLastTick,
            DEBUG_consecutiveScrollSwipeCounterRaw: Int64(_consecutiveScrollSwipeCounter)
        )
        
        if result.timeBetweenTicks > config.consecutiveScrollTickIntervalMax && result.timeBetweenTicks != Double.greatestFiniteMagnitude {
            DDLogWarn("ScrollAnalyzer - smoothed tickTime is over max, clamping. Analysis result: \(ScrollAnalyzer.scrollAnalysisResultDescription(result))")
            result.timeBetweenTicks = config.consecutiveScrollTickIntervalMax
        }
        
        return result
    }
    
    private static func resetSwipes() {
        _consecutiveScrollSwipeCounter = 0
        _consecutiveScrollSwipeCounter_ForFreeScrollWheel = 0
        _consecutiveSwipeSequenceStartTime = CACurrentMediaTime()
        _ticksInCurrentConsecutiveSwipeSequence = 0
        updateTicks()
    }
    
    private static func updateTicks() {
        _consecutiveScrollTickCounter = 0
    }
    
    static func scrollAnalysisResultDescription(_ analysis: ScrollAnalysisResult) -> String {
        let tickTimeStr = analysis.timeBetweenTicks == Double.greatestFiniteMagnitude ? "9999" : String(format: "%f", analysis.timeBetweenTicks)
        return "dirChange: \(analysis.scrollDirectionDidChange ? 1 : 0), ticks: \(analysis.consecutiveScrollTickCounter), swipes: \(analysis.consecutiveScrollSwipeCounter), tickTime: \(tickTimeStr), rawTickTime: \(analysis.DEBUG_timeBetweenTicksRaw), rawSwipes: \(analysis.DEBUG_consecutiveScrollSwipeCounterRaw)"
    }
}

#endif
