//
// --------------------------------------------------------------------------
// TrialNotificationWindow.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

/**
 We want to __increase corner radius__ to somewhat match appearance of system notifications.
 See:
 - https://developer.apple.com/forums/thread/125232
 */

import Cocoa

class TrialNotificationWindow: NSWindow {
    
    override var canBecomeKey: Bool {
        /// This is so the shadow doesn't change when you click on it
        false
    }
}
