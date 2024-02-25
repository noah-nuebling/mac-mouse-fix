//
// --------------------------------------------------------------------------
// Constants.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation

extension CGEventField {
    init(_ mfValue: MFCGEventField) {
        self.init(rawValue: mfValue.rawValue)!
    }
}

extension MFAxis: Hashable { /// So we can use this as dict key
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.rawValue)
    }
}

/// Cache default flags dispatch flags
/// - Usage: pass this to your `dispatchQueue.async` calls to make them a little faster.
/// - For some reason, in the CPU profile I saw that when you call `dispatchQueue.async { <some stuff> }` in TouchAnimatorBase.cancel(), a significant amount of CPU is used to initialize the default `flags: DispatchWorkItemFlags` argument. So use `dispatchQueue.async(flags: defaultDFs) { <some stuff> }` instead to speed things up.
/// - At the time of writing I've adopted this in TouchAnimator and TouchAnimatorBase. Thought about extending DispatchQueue or DispatchWorkItemFlags to make usage automatic, but I don't know how and I don't really think it matters anywhere else performance-wise. (Really it only seemed to matter in the TouchAnimatorBase.cancel() since it's called so much)

let defaultDFs: DispatchWorkItemFlags = []
