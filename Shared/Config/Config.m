//
// --------------------------------------------------------------------------
// Config.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Notes:
/// - [Aug 2025] MMF 3 doesn't support app-specific settings, so all the 'overrides' stuff doesn't apply currently.
/// - We're using our custom coolKeyPath API all over this class, instead of Apple's key-value-coding API (aka KVC) (See valueForKeyPath:). The main reason we do this, is so that, when we set a value at a keypPath which doesn't exist, yet using the function `setConfig(NSString *keyPath, NSObject *value)` then the keyPath is created automatically, instead of just failing. This has the benefit, of being more robust and we don't need to make sure, that all keyPaths already exist in the defaultConfig. In all the other places where we use the coolKeyPath API in this class, we only do this to stay consistent (at the time of writing). I'm not sure, whether our coolKeyPath API is slower that the KVC API. We transitioned over to coolKeyPath API without testing speed.
/// - TODO: Test if the coolKeyPath API is slower than the KVC API and optimize
/// - TODO: Implement callback when frontmost application changes - change settings accordingly
///     ^ Need this when application changes but mouse doesn't move (e.g. Command-Tab). Without this the app specific settings for the new app aren't applied
///     Maybe use NSWorkspaceDidActivateApplicationNotification?
/// iCloud sync:
///      [Aug 2025] `NSUbiquitousKeyValueStore` seems promising
///         This article says it can be used on non-MAS apps, despite what the docs claim: https://blog.scottjlittle.net/2023/05/23/icloud-keyvalue-store.html
///         Questions:
///             - How to resolve conflicts?
///             - What if 2 devices use different config versions?
///             - How to sync with local config?
///             - Will the 1 MB limit always be enough? (If it uses binary plist encoding, it's probably fine.)

#import "Config.h"
#import "AppDelegate.h"
#import "Scroll.h"
#import "ButtonInputReceiver.h"
#import "ScrollModifiers.h"
#import "SharedUtility.h"
#import "Remap.h"
#import "Constants.h"
#import "ModificationUtility.h"
#import "HelperUtility.h"
#import "MFMessagePort.h"
#import "Locator.h"

#if IS_HELPER
#import "Mac_Mouse_Fix_Helper-Swift.h"
#endif

#if IS_MAIN_APP
#import "Mac_Mouse_Fix-Swift.h"
#endif

@implementation Config {
    
    NSString*_configFilePath; /// [Jun 2025] This is currently unused. We're using Locator.m instead.
    NSString *_bundleIDOfAppWhichCausesAppOverride;
//    NSDictionary *_stringToEventFlagMask; /// Delete this
}
@synthesize config=_config, configWithAppOverridesApplied=_configWithAppOverridesApplied;

#pragma mark - Init & singleton instance

+ (void)load_Manual {
    
    /// Create instance
    _instance = [[Config alloc] init];
    
    /// Setup stuff
    ///     Can't do this in `[_instance init]` because the callchain accesses tries to access the `_instance` through `Config.shared`. (Might be fixable by making `handleConfigFileChange()` an instance method like everything else)
    [Config loadFileAndUpdateStates];
    
    
#if IS_HELPER
    /// Setup stuff
    [_instance setupFSEventStreamCallback];
#endif
}

static Config *_instance;
+ (Config *)shared {
    return _instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        /// Get config file path
        NSURL *applicationSupportURL = [NSFileManager.defaultManager URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
        NSString *configFilePathRelative = [NSString stringWithFormat:@"%@/config.plist", kMFBundleIDApp];
        _configFilePath = [applicationSupportURL URLByAppendingPathComponent:configFilePathRelative].path;
    }
    return self;
}

#pragma mark - Convenience

NSObject * _Nullable config(NSString *keyPath) {
    /// Convenience function for accessing config
    NSMutableDictionary *config = Config.shared.config;
    NSObject *result = [config objectForCoolKeyPath:keyPath];
    return result;
}
void setConfig(NSString *keyPath, NSObject *value) {
    /// Convenience function for modifying config
    /// Notes:
    /// - This doesn't write to file. Use commitConfig() for that
    /// - This create the keyPath if it doesn't exist in the config, yet
    
#if DEBUG
    if ([Config.shared.config objectForCoolKeyPath:keyPath] == nil) {
        DDLogDebug(@"Setting value %@ to config at non-existent keyPath %@. The keypath will be created.", value, keyPath);
    }
#endif
    
    [Config.shared.config setObject:value forCoolKeyPath:keyPath];
}
void removeFromConfig(NSString *keyPath) {
    [Config.shared.config removeObjectForCoolKeyPath:keyPath];
}

static NSURL *defaultConfigURL(void) {
    /// `default_config` used to be known as `backup_config`
    ///     We used to get this only once on init, but that breaks after the user moves the app while it's open
    NSString *defaultConfigPathRelative = @"Contents/Resources/default_config.plist";
    return [Locator.mainAppBundle.bundleURL URLByAppendingPathComponent:defaultConfigPathRelative];
}


void commitConfig(void) {
    /// Convenience function for notifying other modules of the changed config (and writing to file)
    
    /// Validate
    assert(NSThread.isMainThread);
    
    /// Write to file
    [Config.shared writeConfigToFile];
    
    /// Notify other app (mainApp notifies helper, helper notifies mainApp
    [MFMessagePort sendMessage:@"configFileChanged" withPayload:nil waitForReply:NO];
    
    /// Update own state
    [Config updateDerivedStates];
}


#pragma mark - React

+ (void)loadFileAndUpdateStates {
    /// Notes:
    ///     This method used to be called `handleConfigFileChange`
    ///     TODO: [Aug 2025] Consider:
    ///         Isn't it an error to call `[loadConfigFromFile]` without calling `[updateDerivedStates]` afterwards? - should we make loadConfigFromFile private?
    [self.shared loadConfigFromFile];
    [self updateDerivedStates];
}

+ (void)updateDerivedStates {
    
    /// Update states across the app that depend on the config.
    /// We should generally call this whenever the config changes.
    
#if IS_MAIN_APP
    [ReactiveConfig.shared reactWithNewConfig:Config.shared.config];

#endif
    
#if IS_HELPER
    
    /// Force update of internal state, (even the active app hastn't changed)
    ///     (Not sure if we need to always do this or only after loading from file)
    [self.shared loadOverridesForApp:@""];
    
    /// Notify other modules
    [Remap reload];
    [ScrollConfig reload];
//    [Scroll decide];
    [PointerConfig reload];
    [GeneralConfig reload];
    [MenuBarItem reload];

#endif
    
}

#pragma mark - Overrides

- (BOOL)loadOverridesForAppUnderMousePointerWithEvent:(CGEventRef)event {
    
    /// Unused in MMF 3
    ///     Reactivate when we reimplement app-specific settings.
    return NO;
    
    /// Returns yes when it's made a change
    /// TODO: Add compatibility for command line executables
    /// TODO: Look into using kCGMouseEventWindowUnderMousePointer to get the window under the mouse pointer
    
    /// Validate
    
    assert(runningHelper());
    
#if IS_HELPER
    
    /// Get bundleID
    NSRunningApplication *app = [HelperUtility appUnderMousePointerWithEvent:event];
    NSString *bundleID = app.bundleIdentifier;
    
    /// Debug
    DDLogDebug(@"Loading overrides for app %@", bundleID);
    
    /// Set internal state
    if (![_bundleIDOfAppWhichCausesAppOverride isEqual:bundleID]) {
        [self loadOverridesForApp:bundleID];
        return YES;
    }
#endif
    
    return NO;
}

/// Applies AppOverrides from app with `bundleIdentifier` to `self->_config` and writes the result into `_configWithAppOverridesApplied`.
- (void)loadOverridesForApp:(NSString *)bundleID {
    
    /// Validate
    assert(runningHelper());
    
#if IS_HELPER
    
    /// Store app
    _bundleIDOfAppWhichCausesAppOverride = bundleID;
    
    /// Get overrides for app
    NSDictionary *overrides = [self->_config objectForKey:kMFConfigKeyAppOverrides];
    NSDictionary *overridesForThisApp;
    for (NSString *b in overrides.allKeys) {
        if ([bundleID isEqualToString:b]) {
                overridesForThisApp = [[overrides objectForKey: b] objectForKey:@"Root"];
        }
    }
    if (overridesForThisApp) {
        _configWithAppOverridesApplied = [[SharedUtility dictionaryWithOverridesAppliedFrom:overridesForThisApp to:self->_config] mutableCopy];
    } else {
        _configWithAppOverridesApplied = self->_config;
    }
#endif
}

#pragma mark - Listen to filesystem changes
/// This stuff is unused in MainApp (and can be removed entirely. Was just for testing.)

- (void)setupFSEventStreamCallback {
    
    /**
     We're setting up a File System Monitor so that manual edits to the main configuration file have an effect.
     This allows you to easily test configurations.
     
     Secret trick to find the main configuration file: Open the Mac Mouse Fix app, and click on "More...". Then, hold Command and Shift while clicking the Mac Mouse Fix Icon in the top left.
     
     Why are we disabling this now?
     In MMF 3 this causes a bug with the addField. And turning this off is the only feasible way I can find to fix that bug.
     
     Explanation of the bug that this caused:
     - When the mainApp writes the config to file it calls `[Config handleConfigFileChange]` . Then the eventStreamCallback calls `[Config handleConfigFileChange]` again - but with a significant delay. Sometimes seems like more than a second. The second, delayed call to `[Config handleConfigFileChange]` leads addMode to be disabled. When the user intends to use addMode that's annoying.
     - To fix this we would either have to ignore FSEvents originating from the mainApp - I haven't found a way to do that. Or we would have to disable the delay with which the FSEvent callback is called. There is a `latency` parameter but even if you set it low there are still usually long delays.
     
     Edit: I have an idea for a fix! Simply disable the eventStream while the mainApp is open / while the messageport is connected! Maybe implement this as part of SwitchMaster
     */
    
    assert(runningHelper());
    
// #if IS_HELPER
#if 0 /// Disable for now
    
    CFArrayRef pathsToWatch;
    void *callbackInfo = NULL; /// Could put stream-specific data here.
    if (@available(macOS 13.0, *)) { /// The old code causes a crash on Ventura (specifically trying to log the cfPath using DDLogInfo)
        NSArray *pathsToWatchNS = @[_configFilePath];
        pathsToWatch = (__bridge_retained CFArrayRef)pathsToWatchNS; /// `__bridge_retained` -> we need to release this manually
    } else {
        CFStringRef cfPath = (__bridge CFStringRef)_configFilePath.copy; /// Why are we copying this?
        CFStringRef cfArray[1] = {cfPath};
        pathsToWatch = CFArrayCreate(NULL, (const void **)cfArray, 1, NULL);
    }
    
    
    DDLogInfo(@"pathsToWatch : %@", (__bridge NSArray *)pathsToWatch);
    
    /// Create eventStream
    /// Notes:
    /// - Not sure if fileEvents flag is a good idea
    /// - Flags ignoreSelf and markSelf seem redundant but this post (https://stackoverflow.com/a/37014613/10601702) says it's necessary. Still kind of unnecessary since Helper never writes to file I think.
    /// - Latency is for optimization I think. Probably totally unnecessary here, but with noDefer it shouldn't make a difference.
    /// - The flag kFSEventStreamCreateFlagUseExtendedData apparently makes a file "inode" available which is something like a low level id. Don't think that's useful for us though.
    
    CFAbsoluteTime latency = 300.0/1000.0;
    FSEventStreamCreateFlags flags = kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagIgnoreSelf | kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagMarkSelf;
    FSEventStreamRef remapsFileEventStream = FSEventStreamCreate(kCFAllocatorDefault, &Handle_FSEventStreamCallback, callbackInfo, pathsToWatch, kFSEventStreamEventIdSinceNow, latency, flags);
    
    /// Start eventStream
    FSEventStreamScheduleWithRunLoop(remapsFileEventStream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    BOOL EventStreamStarted = FSEventStreamStart(remapsFileEventStream);
    DDLogInfo(@"EventStreamStarted: %d", EventStreamStarted);
    
    /// Release stuff
    ///     We might be leaking a bunch of things here in this class but it doesn't matter since it's only run once when the app starts up
    CFRelease(pathsToWatch);
    
#endif
}

void Handle_FSEventStreamCallback(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags *eventFlags, const FSEventStreamEventId *eventIds) {
    
    /// Disable for now (see setupFSEventStreamCallback for explanation)
    assert(false);
    
    /// Gather info
    
    NSArray<NSString *> *paths = (__bridge NSArray *)((CFArrayRef)eventPaths);
    BOOL noInfo = *eventFlags == kFSEventStreamEventFlagNone;
    BOOL isFromSelf = *eventFlags & kFSEventStreamEventFlagOwnEvent;
    BOOL isModified = *eventFlags & kFSEventStreamEventFlagItemModified;
    BOOL isRemoved = *eventFlags & kFSEventStreamEventFlagItemRemoved;
    BOOL isRenamed = *eventFlags & kFSEventStreamEventFlagItemRenamed;
    BOOL isCreated = *eventFlags & kFSEventStreamEventFlagItemCreated;
    BOOL isFile = *eventFlags & kFSEventStreamEventFlagItemIsFile;
    
    /// Log
    
    DDLogInfo(@"FSEvent for config.plist - paths: %@, noInfo: %d, isFromSelf: %d, isModified: %d, isRemoved: %d, isRenamed: %d, isCreated: %d, isFile: %d", paths, noInfo, isFromSelf, isModified, isRemoved, isRenamed, isCreated, isFile);
    
    if (!isFromSelf && isFile) {
        [Config loadFileAndUpdateStates];
    }
}


#pragma mark - Read and write from file

- (void)writeConfigToFile {
    
    /**
     Writes the `self->_config` dictionary to the plist file at `_configURL`
     You probably want to use `commitConfig()` instead of this
     */
    
    if (runningPreRelease()) {
        /// Try to catch crash bug
        ///     On [Feb 20 2025], running the new `3.0.4 Beta 1` I saw NSPropertyListSerialization crash (see stacktrace below)
        ///     My first idea is that this might be caused by our new MFPlistEncoder failing to produce a valid plist, but not sure.
        /// ```
        /// Thread 1 Crashed:
        /// 0   CoreFoundation                	       0x18975202c CF_IS_OBJC + 76
        /// 1   CoreFoundation                	       0x18960a2a8 CFDictionaryGetValue + 56
        /// 2   CoreFoundation                	       0x18967644c _CFAppendXML0 + 3032
        /// 3   CoreFoundation                	       0x189676458 _CFAppendXML0 + 3044
        /// 4   CoreFoundation                	       0x189676458 _CFAppendXML0 + 3044
        /// 5   CoreFoundation                	       0x189713860 _CFPropertyListCreateXMLData + 228
        /// 6   CoreFoundation                	       0x189675628 CFPropertyListCreateData + 240
        /// 7   Foundation                    	       0x18a83471c +[NSPropertyListSerialization dataWithPropertyList:format:options:error:] + 52
        /// 8   Mac Mouse Fix Helper          	       0x1048323c8 -[Config writeConfigToFile] + 76 (Config.m:325)
        /// 9   Mac Mouse Fix Helper          	       0x104832074 commitConfig + 40 (Config.m:118)
        /// 10  Mac Mouse Fix Helper          	       0x10489fff4 specialized static GetLicenseState.storeLicenseStateInCache(_:licenseKey:deviceUID:) + 556 (GetLicenseState.swift:273)
        /// ```
        ///
        /// Sidenote: It would be super nice here to be able to dump custom info into the assertion crash-report!
        ///     We should allow that when we overhaul the error reporting system.
        ///
        bool isValid = CFPropertyListIsValid((__bridge void *)self->_config, kCFPropertyListXMLFormat_v1_0);
        assert(isValid);
    }
    
    NSError *serializeErr;
    NSData *configData = [NSPropertyListSerialization dataWithPropertyList:self->_config format:NSPropertyListXMLFormat_v1_0 options:0 error:&serializeErr];
    if (serializeErr) {
        DDLogInfo(@"ERROR serializing configDictFromFile: %@", serializeErr);
    }
    NSError *writeErr;
    [configData writeToURL:Locator.configURL options:NSDataWritingAtomic error:&writeErr];
    if (writeErr) {
        DDLogInfo(@"ERROR writing configDictFromFile to file: %@", writeErr);
    }
    DDLogInfo(@"Wrote config to file.");
}

NSDictionary *_Nullable _readDictPlist(NSURL *url, bool mutable, NSError * __autoreleasing _Nullable * _Nullable errPtr) {
    
    /// Local helper function for reading our `config.plist` file. [Aug 2025]
    ///
    /// Alternative implementations:
    ///     - Private `+[NSDictionary newWithContentsOf:immutable:error:]` does the exact same thing I think.
    ///         - Public wrapper `[NSMutableDictionary dictionaryWithContentsOfURL:error:]` is declared to return an *immutable* NSDictionary so doesn't quite fit our needs.
    /// Performance:
    ///     - Don't think there's a performance benefit to using `NSPropertyListImmutable`. Evidence: Under macOS 26.0 Tahoe Beta, the system always seems to give us `__NSArrayM` `__NSDictionaryM` (mutable variants) even if we use the immutable `[NSDictionary dictionaryWithContentsOfURL:]` API.

    #define fail(format, args...) ({                            \
        DDLogDebug(@"_readDictPlist: " format, ## args);        \
        return nil;                                             \
    })

    NSError *__autoreleasing localErr;
    if (!errPtr) errPtr = &localErr;
    *errPtr = nil;
    
    NSData *data = [NSData dataWithContentsOfURL: url
                                         options: 0 /// Not totally sure about the options. See https://stackoverflow.com/a/40125866/10601702
                                           error: errPtr];
    if (!data || *errPtr) fail("Reading url %@ failed with error %@", url, *errPtr);
    
    NSMutableDictionary *result = [NSPropertyListSerialization propertyListWithData: data
                                                                            options: (mutable ? NSPropertyListMutableContainersAndLeaves : NSPropertyListImmutable)
                                                                             format: NULL
                                                                              error: errPtr];
    if (!*errPtr) {
        if (!mutable && !isclass(result, NSDictionary))        *errPtr = mferror(NSCocoaErrorDomain, NSPropertyListReadCorruptError, @"Deserialized plist object from %@ is not a dictionary. Is %@",         url, [result class]); /// Error params mostly copied from private `+[NSDictionary newWithContentsOf:immutable:error:]`
        if (mutable  && !isclass(result, NSMutableDictionary)) *errPtr = mferror(NSCocoaErrorDomain, NSPropertyListReadCorruptError, @"Deserialized plist object from %@ is not a mutable dictionary. Is %@", url, [result class]);
    }
    if (!result || *errPtr) fail("Deserializing data at %@ failed with error %@. Result: %@", url, *errPtr, result);
    
    return result;
    #undef fail
}

- (void) loadConfigFromFile {
    
    /// [Aug 2025] Load data from plist file at `Locator.configURL` into `self->_config` class variable
    ///     This only really needs to be called when `Config` is loaded, but I use it in other places as well, to make the program behave better, when I manually edit the config file.
    ///         Update: [Aug 2025] Outdated comment – I think this was referring to the `Handle_FSEventStreamCallback` stuff which is disabled currently.
    
    #if IS_MAIN_APP
        [self _loadAndRepair];
    #else
        NSError *err = nil;
        NSMutableDictionary *config = (id)_readDictPlist(Locator.configURL, true, &err);
        if (!config || err) mfabort(@"Failed to read config file with error: %@. config: %@", err, config); /// [Aug 2025] Should we retry here before aborting?
        self->_config = config;
    #endif
    
    DDLogDebug(@"Loaded config from file: %@", self->_config);
    
    if ((0)) /// -> Disabled because callers of this function now send the reactive signal
        [ReactiveConfig.shared reactWithNewConfig: self->_config];
}

#pragma mark - Repair

- (void) _loadAndRepair {
    
    /// Internal helper for `-[loadConfigFromFile]`

    /// Old todos:
    ///     - Check whether all default (as opposed to override) values exist in config file. If they don't, then everything breaks. Maybe do this by comparing with default_config. Edit: Not sure this is feasible, also the comparing with default_config breaks if we want to have keys that are optional.
    ///         [Aug 2025] 'Overrides' are currently not used since we don't have app-specific settings in MMF 3.
    /// Other considerations:
    ///     - Should we use NSFileCoordinator?
    ///         [Aug 2025] I'm not totally sure what it does. But currently, only the mainApp (not the helper) manipulates the config – and it should only do that from the mainThread – If that's true, then I don't think we need additional coordination.
    ///             Update: [Aug 2025] That is NOT true. The helper does manipulate the config in a few places. E.g. for offline validation in `GetLicenseState.swift` or for the `buttonKillSwitch` / `scrollKillSwitch`.
    
    /// Macros
    {
        /// `fail` macro – Crash if something goes wrong
        ///     - [Aug 2025] We don't wanna accidentally reset the users config due to random file-read error – I think that caused the `Config Reset After Update` / `Config Reset Intermittently` bugs (https://github.com/noah-nuebling/mac-mouse-fix/issues/1510)
        ///         Bug observations:
        ///             - I got like 3 reports about random config-resets recently after 3.0.6, but never before. That's weird. Made me think that new macOS version triggered it. (Those reports caused us to rewrite this code in commit 5858a47a3)
        ///             ... But while debugging the SLSGetLastUsedKeyboardID crashes on Catalina and Big Sur I think I encountered it a a few times. But then I couldn't reproduce it anymore. I think I set the click actions to `Command-,`, `Back`, and `Forward`. And then I made it crash and stuff and the settings got reset a few times. I decided to debug `SLSGetLastUsedKeyboardID` first, but then afterwards (I think i restarted) I couldn't reproduce it anymore.
        ///                 Not sure what's going on. Also my brain is mush so my memory may be wrong.
        ///                 Update: Tried to reproduce the bug on Catalina after the 5858a47a3 rewrite – didn't happen anymore.
        ///             - [Aug 2025] After I wrote the new code, I installed 3.0.0, configured 'Back' and 'Forward' and then launched this build. And it deleted the config! No idea why. Can't reproduce it anymore. Checked the logs from fail() and log() macros and they didn't say anything about replacing IIRC.
        ///                 Only explanation I can think of is that:
        ///                     - 3.0.0 helper somehow replaced the config
        ///                     - I was confused and remember wrong.
        ///                 Thoughts on why this is so weird: ... Only Config.m even knows where the defaultConfig is afaik. And only loadConfigFromFile uses that info. So I really don't know how the app could've reset the config without logging something about that.
        ///     - Other ideas for what to when things fail: (Instead of crashing or replacing)
        ///         - Keep a copy of the old config file before replacing it. -> Better debugging.
        ///         - Retry instead of crashing (Could build retry directly into `_readDictPlist()`)
        #define fail(format, args...) \
            mfabort(@"_loadAndRepair: " format, ## args);
        
        #define log(level, format, args...) \
            DDLog ## level (@"_loadAndRepair: " format, ## args)
    }
    
    /// Asserts
    assert(runningMainApp());       /// [Aug 2025] I think we don't run this on the helper because we think it's a good idea that only the mainApp mutates the config (?) ... Nope the helper manipulates the config in several places – See `commitConfig()` invocations.
    assert(NSThread.isMainThread);  /// [Aug 2025] All the config stuff is not thread safe and should only ever run on one thread I think.
    
    /// Declare
    NSError *err = nil;
    
    /// Load default config
    NSMutableDictionary *defaultConfig = (id)_readDictPlist(defaultConfigURL(), true, &err); /// Read as mutable, since we may assign `self->_config = defaultConfig`
    if (!defaultConfig || err) fail(@"Loading defaultConfig failed with error: %@", err);
    
    /// Load `self->_config`
    self->_config = (id)_readDictPlist(Locator.configURL, true, &err);
    if (!self->_config || err) {
        if (err.domain == NSCocoaErrorDomain && err.code == NSFileReadNoSuchFileError) { /// Create config file if none exists
            log(Info, @"Config file doesn't exist. Creating a new one.");
            err = nil; /// NSFileManager doesn't reset the error
            bool success = [NSFileManager.defaultManager createDirectoryAtURL: Locator.configURL.URLByDeletingLastPathComponent withIntermediateDirectories: YES attributes: nil error: &err]; /// [Aug 2025] Not sure what to choose for the `attributes:`.
            if (!success || err) fail(@"Creating directory for config failed with error %@", err);
            goto replace;
        }
        else
            fail(@"Loading config failed with error: %@", err);
    }
    
    {
        /// Extract versions
        int currentVersion;
        int targetVersion;
        {
            NSNumber *currentVersionNS = (NSNumber *)[self->_config objectForCoolKeyPath:@"Constants.configVersion"];
            NSNumber *targetVersionNS  = (NSNumber *)[defaultConfig objectForCoolKeyPath:@"Constants.configVersion"];
            if (!targetVersionNS)
                fail("Couldn't get default configVersion. MMF bundle must be corrupt/wrong.");
            if (!currentVersionNS) {
                /// [Aug 2025] Not sure if we really wanna replace here. We really don't like false-positive replaces. But at this point we already successfully read the file so the content is probably truly corrupt. Perhaps we should replace here but keep a backup-copy? Crashing could also make sense.
                log(Error, "Couldn't get current configVersion. Something is weird.");
                goto replace;
            }
            currentVersion = currentVersionNS.intValue;
            targetVersion  = targetVersionNS.intValue;
        }
        
        /// Check versions
        if      (currentVersion == targetVersion) { /// If the config version matches – It's all good
            log(Info, "configVersion matches (%d) We can keep using the existing config...", currentVersion);
            goto dontReplace;
        }
        else if (currentVersion > targetVersion) {  /// If config is a downgrade – we don't bother repairing
            log(Info, "configVersion decreased from %d to %d. Not repairing downgrades...", currentVersion, targetVersion);
            goto replace;
        }
        else {                                      /// If config is an upgrade – Attempt to repair                 (See `ConfigReadme.md` for context on what changed between versions)
            log(Info, "configVersion increased from %d to %d. Trying to repair...", currentVersion, targetVersion);
            while (1) {
                
                if (currentVersion == 21) {
                    
                    /// 21 -> 22
                    ///     (21 is used in MMF 3.0.0 I think)
                    ///     (22 is used in MMF 3.0.2 I think)
                    
                    log(Info, "Upgrading configVersion from 21 to 22...");
                    
                    /// Move lastUseDate from config to SecureStorage.
                    NSObject *d = config(@"License.trial.lastUseDate");
                    [SecureStorage set:@"License.trial.lastUseDate" value:d];
                    removeFromConfig(@"License.trial.lastUseDate");
                    
                    currentVersion = 22;
                    
                } else if (currentVersion == 22) {
                    
                    /// 22 -> 23
                    ///     (23 is used in MMF 3.0.2 and 3.0.3)
                    
                    log(Info, "Upgrading configVersion from 22 to 23...");
                    
                    /// Replace default config for 3 buttons
                    ///     NOTE: Maybe we should hardcode the replacement config for 3 buttons? Because the `defaultConfig` might change on future versions.
                    NSObject *d = [defaultConfig objectForCoolKeyPath:@"Constants.defaultRemaps.threeButtons"];
                    setConfig(@"Constants.defaultRemaps.threeButtons", d);
                    
                    currentVersion = 23;
                    
                } else if (currentVersion == 23) {
                
                    /// 23 -> 24
                    ///     (24 will be used in MMF 3.0.4 and later) [Feb 2025]
                    
                    log(Info, "Upgrading configVersion from 23 to 24...");
                    
                    /// Delete legacy MFLicenseState cache values
                    ///     MFLicense state cache moved to a dict at `License.licenseStateCache`, (I've just added that dict in `default_config.plist`) but cache values aren't important enough to copy over to the new location, so we just delete the old values.
                    ///     (Writing this 18 Oct 2024, working on `hyperwork` branch. 3.0.3 is the latest release.)
                    removeFromConfig(@"License.isLicensedCache");
                    removeFromConfig(@"License.licenseReasonCache");
                    
                    currentVersion = 24;
                    
                } else {
                    
                    log(Info, "No upgrades from configVersion %d. Target is %d.", currentVersion, targetVersion);
                    goto replace;
                }
                
                if (currentVersion == targetVersion) {
                    
                    log(Info, "Config was repaired! It was upgraded to configVersion %d.", currentVersion);
                    
                    setConfig(@"Constants.configVersion", @(targetVersion));
                    commitConfig();
                    
                    goto dontReplace;
                }
            }
        }
    }
    
    replace:
    {
        log(Info, "Replacing config with default config...");
        self->_config = defaultConfig;
        commitConfig();
    }
    dontReplace: return;
    
    #undef fail
    #undef log
}

- (void) repairIncompleteAppOverrideForBundleID: (NSString *)bundleID                            /// Bundle ID of the app with the faulty override
                               relevantKeyPaths: (NSArray <NSString *> *)keyPathsToDefaultValues /// KeyPaths to the values of which at least one is missing
{
        
    /// Repair incomplete App override
    ///     Do this by simply copying over the values from the default config
    ///     TODO: Check if this works
    
    assert(false); /// Did some refactors and this is untested and unused at the moment.
    
    DDLogInfo(@"Repairing incomplete appOverrides...");
    
    NSString *bundleIDEscaped = [bundleID stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
    for (NSString *defaultKP in keyPathsToDefaultValues) {
        NSString *overrideKP = [NSString stringWithFormat:@"AppOverrides.%@.Root.%@", bundleIDEscaped, defaultKP];
        if ([self->_config objectForCoolKeyPath:overrideKP] == nil) {
            /// If an override value doesn't exist at overrideKP, put default value at overrideKP.
            [self->_config setObject:[self->_config objectForCoolKeyPath:defaultKP] forCoolKeyPath:overrideKP];
        }
    }
    commitConfig();
}

//- (void)replaceCurrentConfigWithDefaultConfig {
//    
//    /// Replaces the current config file which the helper app is reading from with the backup one and then terminates the helper. (Helper will restart automatically because of the KeepAlive attribute in its user agent config file.)
//    
//    assert(runningMainApp());
//    
//    /// Overwrite `config.plist` with `default_config.plist`
//    NSData *defaultData = [NSData dataWithContentsOfURL:defaultConfigURL()];
//    [defaultData writeToURL:Locator.configURL atomically:YES];
//    
//    /// Update helper
//    ///     Why aren't we just sending a configFileChanged message?
//    [MFMessagePort sendMessage:@"terminate" withPayload:nil waitForReply:NO];
//    
//    /// Update self (mainApp)
////    [self loadConfigFromFile];
//    [Config loadFileAndUpdateStates];
//
//}

- (void)cleanConfig {
    NSMutableDictionary *appOverrides = self->_config[kMFConfigKeyAppOverrides];
    
    /// Note: We don't delete overrides for uninstalled apps because this might delete preinstalled overrides
    
    removeLeaflessSubDicts(appOverrides);
    
    commitConfig(); /// No need to notify the helper at the time of writing
}

static void removeLeaflessSubDicts(NSMutableDictionary *dict) {
    
    /// Delete all paths in the dictionary which don't lead to anything
    // TODO: Implement cleaning function which deletes all overrides that don't change the default config. Adding and removing different apps in ScrollOverridePanel will accumulate dead entries. v is that what I meant?
    
    for (NSString *key in dict.allKeys) {
        NSObject *val = dict[key];
        if ([val isKindOfClass:[NSMutableDictionary class]]) {
            removeLeaflessSubDicts((NSMutableDictionary *)val);
            if (((NSMutableDictionary *)val).count == 0) {
                dict[key] = nil;
            }
        }
    }
}


@end
