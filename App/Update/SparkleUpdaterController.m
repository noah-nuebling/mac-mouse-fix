//
// --------------------------------------------------------------------------
// SparkleUpdateDelegate.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "SparkleUpdaterController.h"
#import "AppDelegate.h"
#import "SharedUtility.h"
#import "Locator.h"
#import "HelperServices.h"
#import "CoolSUVersionComparator.h"

// See https://sparkle-project.org/documentation/customization/



@implementation SparkleUpdaterController

#define CoolSUDidSkipMajorUpdateKey @"CoolSUDidSkipMajorUpdate"     /// Custom key for custom update-skipping-logic
#define CoolSUSkippedMinorVersionKey @"CoolSUSkippedMinorVersion"   /// Custom key for custom update-skipping-logic
#define SUSkippedMinorVersionKey @"SUSkippedVersion" /// By default, Sparkle stores the skipped version under this key in user defaults. Under Sparkle 2 and later, there's also a SUSkippedMajorVersion key. Since we're on Sparkle 1.26.0 we implement sth similar ourselves.

+ (void)resetSkippedVersions {
    [NSUserDefaults.standardUserDefaults removeObjectForKey:CoolSUSkippedMinorVersionKey];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:CoolSUDidSkipMajorUpdateKey];
}

int majorVersion(NSString *version) {
    
    /// Notes:
    /// - This wouldn't work if MMF ever used a v prefix for any version release. E.g. v1.0.0. But we never did, so this should work.
    /// - I think it might be ideal to tap into the `SUStandardVersionComparator`s internal logic, since it already has sophisticated logic to parse the major, minor version, etc. But that's too hard and annoying I think.
    
    return [[version substringToIndex:1] intValue];
}
- (SUAppcastItem *)bestValidUpdateInAppcast:(SUAppcast *)appcast forUpdater:(SUUpdater *)updater {
    
    /// The default logic is to just return the latest update from the appcast.
    /// We also sort of do this, but we add some custom logic on top.
    ///
    /// Custom logic:
    
    /// - 0. If the user skips a major update, that is recorded separately from when the user skips a minor update. (2.0 -> 3.0 is a major update, and 2.2 -> 2.3 is a minor update.)
    ///     - When the user skips a major update, we never show any major update afterwards (until they reset the skipped versions, e.g. by toggling the update checkbox off and on). After skipping a major update, the user will still be presented with the latest minor updates. (After restarting the app once.)
    ///     - When the user skips a minor update x, we don't show minor updates lower or equal to x to the user anymore. But if there's a new minor update y with y > x, then we show y to the user.
    ///     -> This allows users to stay on their current major version, and still receive updates to their current minor version.
    ///     -> Sparkle 2 has a similar feature built in I think. We sort of re-implemented this here on Sparkle 1.26.0. Seemed easier and less risky to reimplement it instead of upgrading to Sparkle 2, but I'm not sure.
    /// - 1. When going to a new major version, we always want to update to the initial x.0.0 release first.
    ///     - That's so the user sees the x.0.0 update notes with all the major changes. 
    ///     - This is especially nice, if the new major version is a paid update, but it's always kind of nice to give the user an intro to the new major version I think.
    /// - 2. Don't jump over major versions. If we're on 0.9, we will be presented with 1.0 next. Then if we're on 1.0, we'll be presented with 2.0 next. We don't skip past major versions.
    ///     - Not totally sure why we're doing this. I guess also just to make major changes more visible. I think it might be nice, especially if those major changes involve pricing. But not sure if necessary.
    /// - 3. xxx If there's a free update, we prioritize that.
    ///     - E.g. MMF 2.2.5 -> 2.2.6 will be presented over 2.2.5 -> 3.0.0 --- because MMF 2 -> MMF 3 is a paid update.
    ///     -> We removed this, because the features we implemented so users can stay on the current major version and still receive updates, solve the same issue as this I think.
    ///
    /// Discussion:
    /// - Discussion/brainstorming for custom logic: https://github.com/noah-nuebling/mac-mouse-fix/issues/962#issuecomment-2120238813
    /// - As far as I understand, the `appcast` arg is already prefiltered by Sparkle using stuff like skippedUpdates, minimumAutoupdateVersion and minimumOSVersion.
    ///   Also, as far as I understand, the default implementation of this method simply uses [delegate versionComparator] (which defaults to a `SUStandardVersionComparator`) to get the appCast item with the highest version.
    ///     - I base these assumptions the following Sparkle 2 source code (we're using Sparkle 1.26.0 at the time of writing, but I hope nothing drastic changed): https://github.com/sparkle-project/Sparkle/blob/2247105ff37ba7b317e65af9833ecbb0f67f81de/Sparkle/SUAppcastDriver.m#L230
    ///         - Update: Things do seem to be different that what I assumed: The `appcast` arg is not prefiltered. Instead it seems like the SUAppCastItem returned by this method is checked by Sparkle against skippedUpdates, minimumAutoupdateVersion, etc.  to decide whether to actually present it.
    /// - I think logically, we're really just implementing a custom comparator. We might be able to achieve the same thing by simply returning a custom SUComparator from this delegate, but I don't think it matters.
    /// - Tip: You can test this pretty well, by just changing the build number and version in Xcode and then building the app and seeing which updates it shows you.
    ///     - After skipping an update, restart the app to see what update you're presented with after the skip. If you retrigger update checks from inside the app (e.g. by toggling the check for updates checkbox) then the skipped versions will also be reset.
    
    
    /// Retrieve skipped versions
    NSInteger skippedMinorVersion = [NSUserDefaults.standardUserDefaults integerForKey:CoolSUSkippedMinorVersionKey];
    BOOL didSkipMajorUpdate = [NSUserDefaults.standardUserDefaults boolForKey:CoolSUDidSkipMajorUpdateKey];
    
    /// Extract updates
    NSArray <SUAppcastItem *> *updates = appcast.items;
    
    /// DEBUG: Shuffle updates
    ///     -> So that we can see if the sorting really works reliably
    
    if ((NO)) {
        void(^shuffleArray)(NSMutableArray *) = ^(NSMutableArray *array) {
            if (array.count <= 1) return;
            for (NSUInteger i = 0; i < array.count - 1; i++) {
                NSInteger remainingCount = array.count - i;
                NSInteger exchangeIndex = i + arc4random_uniform((u_int32_t )remainingCount);
                [array exchangeObjectAtIndex:i withObjectAtIndex:exchangeIndex];
            }
        };
        updates = updates.mutableCopy;
        shuffleArray((id)updates);
    }
    
    /// Declare previous version
    SUAppcastItem *lastUpdateBeforeCurrentVersion = nil;
    
    /// Extract current version
    NSString *currentVersion = Locator.bundleVersionShort;
    int currentMajorVersion = majorVersion(currentVersion);
    NSInteger currentBuildNumber = Locator.bundleVersion;
    
    /// Create comparator
    ///  Note: We're using a cool custom comparator which considers `2.0.0` and `2.0.0 Beta 5` to be the same version.
    NSObject<SUVersionComparison> *comparator = [[CoolSUVersionComparator alloc] init];
    
    /// Find best update in appcast
    SUAppcastItem *bestUpdate = nil;
    for (SUAppcastItem *candidateUpdate in updates) {
        
        /// Init result
        /// Note: On each iteration, our goal is to determine whether the candidateUpdate is better than the current bestUpdate.
        BOOL candidateIsBetter;
        
        /// Extract versions
        NSString *bestVersion = bestUpdate.displayVersionString; /// bestVersion may be nil if bestUpdate is nil
        NSString *candidateVersion = candidateUpdate.displayVersionString;
        NSInteger bestBuildNumber = bestUpdate.versionString.integerValue;
        NSInteger candidateBuildNumber = candidateUpdate.versionString.integerValue;
        
        /// Find last update before currentVersion
        ///     Note: In case we don't find an update that we want to present to the user, we want to return the newest update that Sparkle won't update to - That way Sparkle won't present an update prompt to the user, but we also avoid that Sparkle shows a message saying `Mac Mouse Fix (null) is currently the newest version available.` when you choose `Check for Updates...` from the menu bar. Instead of (null) it will say something less weird.
        if (candidateBuildNumber < currentBuildNumber
            && candidateBuildNumber > lastUpdateBeforeCurrentVersion.versionString.integerValue) {
            
            lastUpdateBeforeCurrentVersion = candidateUpdate;
        }
        
        
        /// Split off major version
        int bestMajorVersion = bestVersion == nil ? -1 : majorVersion(bestVersion);
        int candidateMajorVersion = majorVersion(candidateVersion);
        
        /// Compare version numbers
        BOOL candidateIsLaterThanBest = [comparator compareVersion:bestVersion toVersion:candidateVersion] == NSOrderedAscending;
        BOOL candidateIsEarlierThanBest = [comparator compareVersion:bestVersion toVersion:candidateVersion] == NSOrderedDescending;
        BOOL candidateIsSameVersionAsBest = !candidateIsLaterThanBest && !candidateIsEarlierThanBest;
        
        BOOL candidateIsLaterThanCurrent = [comparator compareVersion:currentVersion toVersion:candidateVersion] == NSOrderedAscending;
        BOOL candidateIsEarlierThanCurrent = [comparator compareVersion:currentVersion toVersion:candidateVersion] == NSOrderedDescending;
        BOOL candidateIsSameVersionAsCurrent = !candidateIsLaterThanCurrent && !candidateIsEarlierThanCurrent;
        
        /// Debug
        NSLog(@"DEBUG Comparing current best update: %@ (mv %d, bn %d), with candidate update: %@ (mv %d, bn %d) --- Current version %@ (mv %d, bn %d)", bestVersion, bestMajorVersion, bestBuildNumber, candidateVersion, candidateMajorVersion, candidateBuildNumber, currentVersion, currentMajorVersion, currentBuildNumber);
        
        /// Determine free vs paid updates
        ///     Note: Disabling this. Wrote explanation at the top somewhere.
        if ((NO)) {
            BOOL(^isFreeUpdate)(int, int) = ^(int currentMajorVersion, int updateMajorVersion) {
                
                BOOL updateIsFree = currentMajorVersion >= updateMajorVersion; /// If the update doesn't have a higher major version, it's definitely free, otherwise we initialize to not free.
                
                if (updateMajorVersion == -1) {       ///  Does this case matter?
                    
                } else if (updateMajorVersion == 1) { /// `MMF 0.9 -> MMF 1` is a free update
                    updateIsFree = YES;
                } else if (updateMajorVersion == 2) { /// `MMF 0.9 -> MMF 2` and `MMF 1 -> MMF 2` are free updates
                    updateIsFree = YES;
                }
                return updateIsFree;
            };
            
            BOOL candidateIsFreeUpdate = isFreeUpdate(currentMajorVersion, candidateMajorVersion);
            BOOL bestIsFreeUpdate = isFreeUpdate(currentMajorVersion, bestMajorVersion);
        }
        
        /// Determine whether the candidate update is better than the `best` update
        
        /// Rule 0: Skip older/equal versions
        ///     Notes:
        ///     - I thought Sparkle would already filter older versions out, but apparently not.
        ///     - I think I based this assumption on reading the Sparkle 2 source code. Maybe it's different here since we're on Sparkle 1.26.0.
        ///     - I think if we return an update for which Sparkle determines that it's invalid due to skippedUpdates, minimumAutoupdateVersion and minimumOSVersion, then Sparkle will just not display the update we return. But not sure. TODO: Test this.
        
        if (candidateIsEarlierThanCurrent ||
            (candidateIsSameVersionAsCurrent && candidateBuildNumber <= currentBuildNumber)) {
            
            candidateIsBetter = NO;
            goto loopEnd;
        }
        
        /// Rule 0.1: Respect skipped versions
        if (candidateBuildNumber <= skippedMinorVersion) {
            
            candidateIsBetter = NO;
            goto loopEnd;
        }
        if (didSkipMajorUpdate && candidateMajorVersion > currentMajorVersion) {
            
            candidateIsBetter = NO;
            goto loopEnd;
        }
        
        /// Rule 1: We always prioritize free updates
        ///     Note: I think it's better without this, since even without this, the user will be prompted to update to next major version. And if they skip it, they will instead see minor version updates. That's good enough and consistent, and we won't have to have some up-to-date database about which updates are free/paid.
//        if (bestUpdate != nil
//            && candidateIsFreeUpdate != bestIsFreeUpdate) {
//            
//            candidateIsBetter = candidateIsFreeUpdate;
//            goto loopEnd;
//        }
        
        /// Rule 2: When jumping to a new major version - update to the initial release of that major version.
        ///     Note: If we're currently on 1.0 and comparing updates 2.2.3 and 2.0.0, it will prefer 2.0.0 - because that's the smaller version number. But it won't prefer 2.0.0 Beta 13, cause that is the same version number (2.0.0) - and we're not comparing build numbers here.
        if (candidateMajorVersion == bestMajorVersion       /// If we're deciding between two versions of the same major release
            && candidateMajorVersion > currentMajorVersion  /// ... And that major release is different from the current major release
            && !candidateIsSameVersionAsBest) {             /// ... And the two versions we're deciding between don't have the same version number.
            
            candidateIsBetter = !candidateIsLaterThanBest;          /// ... Then we always choose the older release
            goto loopEnd;
        }
        
        /// Rule 3: Prefer smaller change of the major version
        ///     Note: So if we are on 0.9, we update to 1.0 instead of going straight to 2.0
        if (candidateMajorVersion != bestMajorVersion
            && candidateMajorVersion > currentMajorVersion
            && bestMajorVersion > currentMajorVersion) {
            
            candidateIsBetter = candidateMajorVersion < bestMajorVersion;
            goto loopEnd;
        }
        
        /// Validate
        assert(!candidateIsEarlierThanCurrent); /// This case should be filtered out by logic above
        
        /// Rule 4: Otherwise, update to the later version
        
        if (candidateIsLaterThanBest) {
            candidateIsBetter = YES;
            goto loopEnd;
        } else if (candidateIsEarlierThanBest) {
            candidateIsBetter = NO;
            goto loopEnd;
        }
        
        /// Validate
        assert(candidateBuildNumber > currentBuildNumber);
        
        /// Rule 5: If both versions are the same (which is the case here since Rule 3 didn't decide anything) -> compare the build number instead
        /// Notes:
        /// - This is used to differentiate between different versions with the same beginning such as`2.0.0` and `2.0.0 Beta 5` - this is only possible because of our custom `CoolSUVersionComparator` which considers `2.0.0` and `2.0.0 Beta 5` to be the same version unlike the default Sparkle 1.26.0 comparator.
        
        if (candidateBuildNumber > bestBuildNumber) { /// Not sure how important it is that here we're choosing `>` over `>=`
            candidateIsBetter = YES;
            goto loopEnd;
        } else {
            candidateIsBetter = NO;
            goto loopEnd;
        }
        
    loopEnd:
        if (candidateIsBetter) {
            bestUpdate = candidateUpdate;
        }
        
    }
    
    /// Return an update
    
    if (bestUpdate == nil) {
        if (lastUpdateBeforeCurrentVersion != nil) {
            return lastUpdateBeforeCurrentVersion;  /// Newest update which Sparkle (1.26.0) won't present to the user. Explanation above somewhere.
        } else {
            NSLog(@"DEBUG Returning nil appcastItem to Sparkle because we couldn't find a lastUpdateBeforeCurrentVersion. This normally shouldn't happen I think, except if the build number of this build is very low.");
            return [[SUAppcastItem alloc] init];    /// If we return nil Sparkle (1.26.0) will just show the latest udpate to the user which we want to avoid.
        }
    } else {
        return bestUpdate;
    }
}

- (void)updater:(SUUpdater *)updater userDidSkipThisVersion:(SUAppcastItem *)item {
    
    NSLog(@"User skipped version %@", item.displayVersionString);
    
    int skippedMajorVersion = majorVersion(item.displayVersionString);
    int currentMajorVersion = majorVersion(Locator.bundleVersionShort);
    
    BOOL isMajorUpdate = skippedMajorVersion > currentMajorVersion;
    
    if (isMajorUpdate) {
        [NSUserDefaults.standardUserDefaults setBool:YES forKey:CoolSUDidSkipMajorUpdateKey];
    } else {
        [NSUserDefaults.standardUserDefaults setInteger:[item.versionString integerValue] forKey:CoolSUSkippedMinorVersionKey];
    }
    
    /// Do stuff after delay
    /// Note:
    /// - Not sure what the delay should be. Did zero testing. 1.0 is probably much higher than necessary, but seems to work alright.
    /// - The optimal delay for the diffent stuff we do here might also be different. But it works ok.
    
    float delayInSeconds = 1.0;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        /// Remove the default Sparkle key so we can handle things ourselves.
        [NSUserDefaults.standardUserDefaults removeObjectForKey:SUSkippedMinorVersionKey];
        
        /// Check for updates again. Due to our custom updating logic, this might present a minor update right after the user skipped a major update.
        [updater checkForUpdatesInBackground];
    });
}

+ (void)enablePrereleaseChannel:(BOOL)pre {
    if (pre) {
        SUUpdater.sharedUpdater.feedURL = [NSURL URLWithString:stringf(@"%@/%@", kMFUpdateFeedRepoAddressRaw, kSUFeedURLSubBeta)];
    } else {
        SUUpdater.sharedUpdater.feedURL = [NSURL URLWithString:stringf(@"%@/%@", kMFUpdateFeedRepoAddressRaw, kSUFeedURLSub)];
    }
}

- (BOOL)updaterShouldPromptForPermissionToCheckForUpdates:(SUUpdater *)updater {
    /// We don't use Sparkles automatic scheduled updates anyways. Instead we simply check every time the app is started. So what the user chooses in this prompt doesn't make difference anyways. So were disabling the prompts.
    return NO;
}

- (void)updater:(SUUpdater *)updater willInstallUpdate:(SUAppcastItem *)update {
    
    NSLog(@"About to install update");
    
    [MoreSheet.instance end]; /// Close more sheet so it doesn't block popup
}

- (void)updaterDidRelaunchApplication:(SUUpdater *)updater {
    
    NSLog(@"Has been launched by Sparkle Updater");
    
    /// Log the fact that updater launched the application in appState()
    ///     We use this from `AppDelegate - applicationDidFinishLaunching`.
    appState().updaterDidRelaunchApplication = YES;
    
    /// Kill helper
    /// It might be more robust and simple to find and kill any strange helpers *whenever* the app starts, but this should work, too.
    [HelperServices killAllHelpers];
    
}




@end
