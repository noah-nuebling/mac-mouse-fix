
//
// --------------------------------------------------------------------------
// AppOverrides.swift
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

// Based on:

//
//  ScrollUtils.swift
//  Mos
//  滚动事件截取与判断核心工具方法
//  Created by Caldis on 2018/2/19.
//  Copyright © 2018年 Caldis. All rights reserved.
//


import Foundation
import Cocoa

@objc class AppOverrides: NSObject {
    
    override init() {
    }
    
    
    let systemWideElement = AXUIElementCreateSystemWide();
    var bundleIdCache:String? = nil
    var bundleIdDetectTime = 0.0
    var mouseLocationCache = NSPoint(x: 0.0, y: 0.0)
        

    public func getBundleIdFromMouseLocation(and event: CGEvent) -> String? {
        
        print("Swift Called!");
        
        let ts: CFTimeInterval = CACurrentMediaTime();
        
        let location = NSEvent.mouseLocation
        // 如果距离上次检测时间大于 1000ms, 且鼠标移动大于阈值, 或缓存值为空, 则重新检测一遍, 否则直接返回上次的结果
        let nowTime = NSDate().timeIntervalSince1970
        if nowTime-bundleIdDetectTime>1.0 && !mouseStayStill(location, mouseLocationCache) || bundleIdCache==nil {
            // 获取坐标下的元素信息
            var element: AXUIElement?
            let pointAsCGPoint = carbonScreenPointFromCocoaScreenPoint(mouseLocation: location)
            let copyElementRes = AXUIElementCopyElementAtPosition(systemWideElement, Float(pointAsCGPoint.x), Float(pointAsCGPoint.y), &element )
            // 更新缓存值
            mouseLocationCache = location
            bundleIdDetectTime = nowTime
            // 先尝试从鼠标坐标查找, 如果无法找到, 则使用事件携带的信息查找
            if copyElementRes == .success {
                let pid = getPidFrom(element: element!)
                bundleIdCache = getApplicationBundleIdFrom(pid: pid)
            } else {
                bundleIdCache = getCurrentEventTargetBundleId(from: event)
            }
        }
        
        print("MOS app under mouse pointer benchmark: \(CACurrentMediaTime() - ts)");
        
        return bundleIdCache
    }

    let limit:CGFloat = 20
    func mouseStayStill(_ a: CGPoint, _ b: CGPoint) -> Bool {
        return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2)) < limit
    }

    private func carbonScreenPointFromCocoaScreenPoint(mouseLocation point: NSPoint) -> CGPoint {
        var foundScreen: NSScreen?
        var targetPoint: CGPoint?
        for screen in NSScreen.screens {
            if NSPointInRect(point, screen.frame) {
                foundScreen = screen
            }
        }
        if let screen = foundScreen {
            let screenHeight = screen.frame.size.height
            targetPoint = CGPoint(x: point.x, y: screenHeight - point.y - 1)
        }
        return targetPoint ?? CGPoint(x: 0.0, y: 0.0)
    }

    private func getPidFrom(element: AXUIElement) -> pid_t {
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        return pid
    }
    private func getApplicationBundleIdFrom(pid: pid_t) -> String? {
        if let runningApps = NSRunningApplication.init(processIdentifier: pid) {
            return runningApps.bundleIdentifier
        } else {
            return nil
        }
    }
    private var lastEventTargetPID:pid_t = 1     // 目标进程 PID (先前)
    private var currEventTargetPID:pid_t = 1     // 事件的目标进程 PID (当前)
    private var currEventTargetBID:String?       // 事件的目标进程 BID (当前)
    func getCurrentEventTargetBundleId(from event: CGEvent) -> String? {
        // 保存上次 PID
        lastEventTargetPID = currEventTargetPID
        // 更新当前 PID
        currEventTargetPID = pid_t(event.getIntegerValueField(.eventTargetUnixProcessID))
        // 使用 PID 获取 BID
        // 如果目标 PID 变化, 则重新获取一次窗口 BID (查找 BID 效率较低)
        if lastEventTargetPID != currEventTargetPID {
            if let bundleId = getApplicationBundleIdFrom(pid: currEventTargetPID) {
                currEventTargetBID = bundleId
                return currEventTargetBID
            }
        }
        return currEventTargetBID
    }
}
