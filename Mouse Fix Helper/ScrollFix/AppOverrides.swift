
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

func getBundleIdFromMouseLocation(and event: CGEvent) -> String? {
    
    let ts: CFTimeInterval = CACurrentMediaTime();
    
    let location = NSEvent.mouseLocation
    // 如果距离上次检测时间大于 1000ms, 且鼠标移动大于阈值, 或缓存值为空, 则重新检测一遍, 否则直接返回上次的结果
    let nowTime = NSDate().timeIntervalSince1970
    if nowTime-self.bundleIdDetectTime>1.0 && !mouseStayStill(location, mouseLocationCache) || bundleIdCache==nil {
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
