//
// --------------------------------------------------------------------------
// ScrollUtility.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#if IS_HELPER

import Cocoa
import IOKit

private let kCGScrollWheelEventDeltaAxis1 = CGEventField.scrollWheelEventDeltaAxis1
private let kCGScrollWheelEventDeltaAxis2 = CGEventField.scrollWheelEventDeltaAxis2
private let kCGScrollWheelEventPointDeltaAxis1 = CGEventField.scrollWheelEventPointDeltaAxis1
private let kCGScrollWheelEventPointDeltaAxis2 = CGEventField.scrollWheelEventPointDeltaAxis2
private let kCGScrollWheelEventFixedPtDeltaAxis1 = CGEventField.scrollWheelEventFixedPtDeltaAxis1
private let kCGScrollWheelEventFixedPtDeltaAxis2 = CGEventField.scrollWheelEventFixedPtDeltaAxis2

@objc public enum MFDisplayLinkPhase: Int {
    case none = 0
    case start = 1
    case linear = 2
    case momentum = 3
    case end = 4
}

@objc(ScrollUtility)
public class ScrollUtility: NSObject {
    
    @objc public static let MFScrollPhaseToIOHIDEventPhase: NSDictionary = [
        MFDisplayLinkPhase.none.rawValue: kIOHIDEventPhaseUndefined,
        MFDisplayLinkPhase.start.rawValue: kIOHIDEventPhaseBegan,
        MFDisplayLinkPhase.linear.rawValue: kIOHIDEventPhaseChanged,
        MFDisplayLinkPhase.momentum.rawValue: kIOHIDEventPhaseChanged,
        MFDisplayLinkPhase.end.rawValue: kIOHIDEventPhaseEnded
    ]
    
    @objc public static func createPixelBasedScrollEvent(withValuesFrom event: CGEvent) -> CGEvent? {
        guard let newEvent = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: 0, wheel2: 0, wheel3: 0) else {
            return nil
        }
        let valueFields = [
            kCGScrollWheelEventDeltaAxis1,
            kCGScrollWheelEventDeltaAxis2,
            kCGScrollWheelEventPointDeltaAxis1,
            kCGScrollWheelEventPointDeltaAxis2,
            kCGScrollWheelEventFixedPtDeltaAxis1,
            kCGScrollWheelEventFixedPtDeltaAxis2
        ]
        for field in valueFields {
            let ogVal = event.getIntegerValueField(field)
            newEvent.setIntegerValueField(field, value: ogVal)
        }
        return newEvent
    }
    
    @objc public static func createNormalizedEvent(withPixelValue lineHeight: Int32) -> CGEvent? {
        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: 0, wheel2: 0, wheel3: 0) else {
            return nil
        }
        event.setIntegerValueField(kCGScrollWheelEventDeltaAxis1, value: 1)
        event.setIntegerValueField(kCGScrollWheelEventPointDeltaAxis1, value: Int64(lineHeight))
        event.setDoubleValueField(kCGScrollWheelEventFixedPtDeltaAxis1, value: Double(lineHeight))
        
        DDLogInfo("Normalized scroll event values:")
        DDLogInfo("\(event.getIntegerValueField(kCGScrollWheelEventDeltaAxis1))")
        DDLogInfo("\(event.getIntegerValueField(kCGScrollWheelEventPointDeltaAxis1))")
        DDLogInfo("\(event.getDoubleValueField(kCGScrollWheelEventFixedPtDeltaAxis1))")
        
        return event
    }
    
    @objc public static func invertScrollEvent(_ event: CGEvent, direction: Int32) -> CGEvent {
        let dir = Int64(direction)
        // invert vertical
        let line1 = event.getIntegerValueField(kCGScrollWheelEventDeltaAxis1)
        let point1 = event.getIntegerValueField(kCGScrollWheelEventPointDeltaAxis1)
        let fixedPt1 = event.getIntegerValueField(kCGScrollWheelEventFixedPtDeltaAxis1)
        event.setIntegerValueField(kCGScrollWheelEventDeltaAxis1, value: line1 * dir)
        event.setIntegerValueField(kCGScrollWheelEventPointDeltaAxis1, value: point1 * dir)
        event.setIntegerValueField(kCGScrollWheelEventFixedPtDeltaAxis1, value: fixedPt1 * dir)
        // invert horizontal
        let line2 = event.getIntegerValueField(kCGScrollWheelEventDeltaAxis2)
        let point2 = event.getIntegerValueField(kCGScrollWheelEventPointDeltaAxis2)
        let fixedPt2 = event.getIntegerValueField(kCGScrollWheelEventFixedPtDeltaAxis2)
        event.setIntegerValueField(kCGScrollWheelEventDeltaAxis2, value: line2 * dir)
        event.setIntegerValueField(kCGScrollWheelEventPointDeltaAxis2, value: point2 * dir)
        event.setIntegerValueField(kCGScrollWheelEventFixedPtDeltaAxis2, value: fixedPt2 * dir)
        return event
    }
    
    @objc public static func makeScrollEventHorizontal(_ event: CGEvent) -> CGEvent {
        let line1 = event.getIntegerValueField(kCGScrollWheelEventDeltaAxis1)
        let point1 = event.getIntegerValueField(kCGScrollWheelEventPointDeltaAxis1)
        let fixedPt1 = event.getIntegerValueField(kCGScrollWheelEventFixedPtDeltaAxis1)
        
        event.setIntegerValueField(kCGScrollWheelEventDeltaAxis1, value: 0)
        event.setIntegerValueField(kCGScrollWheelEventPointDeltaAxis1, value: 0)
        event.setIntegerValueField(kCGScrollWheelEventFixedPtDeltaAxis1, value: 0)
        
        event.setIntegerValueField(kCGScrollWheelEventDeltaAxis2, value: line1)
        event.setIntegerValueField(kCGScrollWheelEventPointDeltaAxis2, value: point1)
        event.setIntegerValueField(kCGScrollWheelEventFixedPtDeltaAxis2, value: fixedPt1)
        
        return event
    }
    
    @objc public static func logScrollEvent(_ event: CGEvent) {
        let line1 = event.getIntegerValueField(kCGScrollWheelEventDeltaAxis1)
        let point1 = event.getIntegerValueField(kCGScrollWheelEventPointDeltaAxis1)
        let fixedPt1 = event.getIntegerValueField(kCGScrollWheelEventFixedPtDeltaAxis1)
        
        let line2 = event.getIntegerValueField(kCGScrollWheelEventDeltaAxis2)
        let point2 = event.getIntegerValueField(kCGScrollWheelEventPointDeltaAxis2)
        let fixedPt2 = event.getIntegerValueField(kCGScrollWheelEventFixedPtDeltaAxis2)
        
        DDLogInfo("Axis 1:")
        DDLogInfo("  Line: \(line1)")
        DDLogInfo("  Point: \(point1)")
        DDLogInfo("  FixedPt: \(fixedPt1)")
        
        DDLogInfo("Axis 2:")
        DDLogInfo("  Line: \(line2)")
        DDLogInfo("  Point: \(point2)")
        DDLogInfo("  FixedPt: \(fixedPt2)")
    }
    
    @objc public static func point(_ p1: CGPoint, isAboutTheSameAs p2: CGPoint, threshold: Int32) -> Bool {
        if abs(Int(p2.x - p1.x)) > Int(threshold) || abs(Int(p2.y - p1.y)) > Int(threshold) {
            return false
        }
        return true
    }
    
    @objc public static func sameSign(_ n: Double, and m: Double) -> Bool {
        if n == 0 || m == 0 {
            return true
        }
        if mfsign(n) == mfsign(m) {
            return true
        }
        return false
    }
    
    @objc public static func axisForVerticalDelta(_ deltaV: Int64, horizontalDelta deltaH: Int64) -> MFAxis {
        assert(deltaV == 0 || deltaH == 0, "Scroll event is not parallel to an axis.")
        var axis = kMFAxisVertical
        if deltaH != 0 {
            axis = kMFAxisHorizontal
        }
        return axis
    }
    
    @objc public static func directionForInputAxis(_ axis: MFAxis,
                                                  inputDelta: Int64,
                                                  invertSetting: MFScrollInversion,
                                                  horizontalModifier: Bool) -> MFDirection {
        let inputAxisDirection = mfsign(Double(inputDelta))
        let effectiveAxisDirection = Int32(inputAxisDirection) * invertSetting.rawValue
        
        if axis == kMFAxisHorizontal || horizontalModifier {
            if effectiveAxisDirection == -1 {
                return kMFDirectionLeft
            } else {
                return kMFDirectionRight
            }
        } else {
            if effectiveAxisDirection == -1 {
                return kMFDirectionDown
            } else {
                return kMFDirectionUp
            }
        }
    }
    
    private static var _mouseDidMove: Bool = false
    @objc public static var mouseDidMove: Bool {
        return _mouseDidMove
    }
    
    private static var _previousMouseLocation: CGPoint = .zero
    @objc public static func updateMouseDidMoveWithEvent(_ event: CGEvent) {
        let mouseLocation = event.location
        _mouseDidMove = !ScrollUtility.point(mouseLocation,
                                             isAboutTheSameAs: _previousMouseLocation,
                                             threshold: 10)
        _previousMouseLocation = mouseLocation
    }
    
    private static var _frontMostAppDidChange: Bool = false
    @objc public static var frontMostAppDidChange: Bool {
        return _frontMostAppDidChange
    }
    
    private static var _previousFrontMostApp: NSRunningApplication?
    @objc public static func updateFrontMostAppDidChange() {
        let frontMostApp = NSWorkspace.shared.frontmostApplication
        _frontMostAppDidChange = (frontMostApp != _previousFrontMostApp)
        _previousFrontMostApp = frontMostApp
    }
}

#endif
