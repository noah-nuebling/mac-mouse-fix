//
// --------------------------------------------------------------------------
// TestLogging.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

@objc class TestLoggingSwift: NSObject {
    
    @objc static func doTestLogs_swift() {
        
        print("Begin doTestLogs_swift");
        print("Test DDLogError:");
        DDLogError("DDLogError is logging (Swift)");
        print("Test DDLogWarn:");
        DDLogWarn("DDLogWarn is logging (Swift)");
        print("Test DDLogInfo:");
        DDLogInfo("DDLogInfo is logging (Swift)");
        print("Test DDLogDebug:");
        DDLogDebug("DDLogDebug is logging (Swift)");
        print("End doTestLogs_swift");
    }
}
