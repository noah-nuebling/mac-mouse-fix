//
// --------------------------------------------------------------------------
// ModifiedDragOutputThreeFingerSwipe.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022 (Translated to Swift in 2026)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation
import CoreGraphics
import Cocoa

@objc(ModifiedDragOutputThreeFingerSwipe)
class ModifiedDragOutputThreeFingerSwipe: NSObject, ModifiedDragOutputPlugin {
    
    private weak var drag: ModifiedDragState?
    
    private var nOfSpaces: Int16 = 1
    
    private var verticalIsUpward: Bool = false
    private var horizontalIsLeftward: Bool = false
    private var spaceSwitchSymbolicHotKeyFired: Bool = false
    
    private var appExposeSymbolicHotKeyFired: Bool = false
    private var missionControlSymbolicHotKeyFired: Bool = false
    
    func initialize(with dragState: ModifiedDragState) {
        self.drag = dragState
    }
    
    func handleBecameInUse() {
        guard let drag = self.drag else { return }
        
        // 使用宏定义的 kCGSAllSpacesMask 获取全部 Space 信息
        if let spaces = CGSCopySpaces(CGSMainConnectionID(), kCGSAllSpacesMask) {
            let uniqueSpaces = Set(spaces.takeUnretainedValue() as? [AnyHashable] ?? [])
            nOfSpaces = Int16(uniqueSpaces.count)
        }
        
        if drag.usageAxis == kMFAxisVertical {
            verticalIsUpward = drag.originOffset.y < 0
            appExposeSymbolicHotKeyFired = false
            missionControlSymbolicHotKeyFired = false
        } else if drag.usageAxis == kMFAxisHorizontal {
            horizontalIsLeftward = drag.originOffset.x < 0
            spaceSwitchSymbolicHotKeyFired = false
        }
        
        if GeneralConfig.freezePointerDuringModifiedDrag() {
            PointerFreeze.freezePointer(atPosition: drag.usageOrigin)
        }
    }
    
    func handleMouseInputWhileInUse(deltaX: Double, deltaY: Double, event: CGEvent?) {
        guard let drag = self.drag else { return }
        
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        let originOffsetForOneSpace = nOfSpaces == 1 ? 2.0 : 1.0 + (1.0 / Double(nOfSpaces - 1))
        let spaceSeparatorWidth = 63.0
        let threeFingerScaleH = originOffsetForOneSpace / (screenSize.width + spaceSeparatorWidth)
        
        let threeFingerScaleV = 1.0 / Double(screenSize.height)
        
        let beganPhase = IOHIDEventPhaseBits(kIOHIDEventPhaseBegan)
        let changedPhase = IOHIDEventPhaseBits(kIOHIDEventPhaseChanged)
        let eventPhase = drag.firstCallback ? beganPhase : changedPhase
        
        if drag.usageAxis == kMFAxisHorizontal {
            // 水平轻扫 —— 桌面空间切换
            let delta = -deltaX * threeFingerScaleH
            TouchSimulator.postDockSwipeEvent(
                withDelta: delta,
                type: kMFDockSwipeTypeHorizontal,
                phase: eventPhase,
                invertedFromDevice: drag.naturalDirection
            )
            
            if !spaceSwitchSymbolicHotKeyFired {
                spaceSwitchSymbolicHotKeyFired = true
                let shk = horizontalIsLeftward ? kMFSHMoveRightASpace : kMFSHMoveLeftASpace
                SymbolicHotKeys.post(CGSSymbolicHotKey(shk.rawValue))
            }
            
        } else if drag.usageAxis == kMFAxisVertical {
            if verticalIsUpward {
                // 向上拉起 —— Mission Control
                let delta = deltaY * threeFingerScaleV
                TouchSimulator.postDockSwipeEvent(
                    withDelta: delta,
                    type: kMFDockSwipeTypeVertical,
                    phase: eventPhase,
                    invertedFromDevice: drag.naturalDirection
                )
                
                if !missionControlSymbolicHotKeyFired {
                    missionControlSymbolicHotKeyFired = true
                    SymbolicHotKeys.post(CGSSymbolicHotKey(kMFSHMissionControl.rawValue))
                }
            } else {
                // 向下拉起 —— App Exposé
                let delta = deltaY * threeFingerScaleV
                TouchSimulator.postDockSwipeEvent(
                    withDelta: delta,
                    type: kMFDockSwipeTypeVertical,
                    phase: eventPhase,
                    invertedFromDevice: drag.naturalDirection
                )
                
                if !appExposeSymbolicHotKeyFired {
                    appExposeSymbolicHotKeyFired = true
                    SymbolicHotKeys.post(CGSSymbolicHotKey(kMFSHAppExpose.rawValue))
                }
            }
        }
    }
    
    func handleDeactivationWhileInUse(cancel: Bool) {
        guard let drag = self.drag else { return }
        
        let cancelledPhase = IOHIDEventPhaseBits(kIOHIDEventPhaseCancelled)
        let endedPhase = IOHIDEventPhaseBits(kIOHIDEventPhaseEnded)
        let phase = cancel ? cancelledPhase : endedPhase
        
        if drag.usageAxis == kMFAxisHorizontal {
            TouchSimulator.postDockSwipeEvent(
                withDelta: 0.0,
                type: kMFDockSwipeTypeHorizontal,
                phase: phase,
                invertedFromDevice: drag.naturalDirection
            )
        } else if drag.usageAxis == kMFAxisVertical {
            TouchSimulator.postDockSwipeEvent(
                withDelta: 0.0,
                type: kMFDockSwipeTypeVertical,
                phase: phase,
                invertedFromDevice: drag.naturalDirection
            )
        }
        
        if GeneralConfig.freezePointerDuringModifiedDrag() {
            PointerFreeze.unfreeze()
        }
    }
    
    func suspend() {}
    func unsuspend() {}
}
