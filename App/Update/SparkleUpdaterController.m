//
// --------------------------------------------------------------------------
// SparkleUpdateDelegate.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "SparkleUpdaterController.h"
#import "AppDelegate.h"
#import "SharedUtility.h"
#import "Locator.h"
#import "HelperServices.h"
#import "CoolSUComparator.h"
#import "Logging.h"

// See https://sparkle-project.org/documentation/customization/



@implementation SparkleUpdaterController

#define CoolSUSkippedMajorVersionKey @"CoolSUSkippedMajorVersion"   /// Custom key for custom update-skipping-logic
#define CoolSUSkippedMinorVersionKey @"CoolSUSkippedMinorVersion"   /// Custom key for custom update-skipping-logic
#define SUSkippedMinorVersionKey @"SUSkippedVersion" /// By default, Sparkle stores the skipped version under this key in user defaults. Under Sparkle 2 and later, there's also a SUSkippedMajorVersion key. Since we're on Sparkle 1 we implement sth similar ourselves.

+ (void)resetSkippedVersions {
    
    /// Delete the users choice about which updates they'd like to skip
    ///
    /// I think this should be invoked at the following times:
    /// - 1. When the user disables and then re-enables the "Check for Updates" checkbox
    ///     - Why: This behavior makes intuitive sense to me. Can't explain. In MMF 2 there's also a tooltop on the "Check for Updates" checkbox that explains this behavior.
    /// - 2. When the user chooses "Check for Updates..." from the Menu Bar
    ///     - Why: This is the behavior that Sparkles expects. If our `bestValidUpdateInAppcast:` method then decides that we don't want to show any update to the user (by returning an update that has a lower build number than the user's current build number), Sparkles then shows a popup saying `<bestValidUpdateInAppcast> is the latest available version`. So to make this Sparkle popup say the truth, we need to remove the skipped versions (And theoretically any other filters we apply to the appCast). We could also make the Sparkle popup say the truth by somehow ignoring skipped versions during those user-initiated checks. But not sure how that would be easily possible. And I like the current behavior
    
    [NSUserDefaults.standardUserDefaults removeObjectForKey:CoolSUSkippedMinorVersionKey];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:CoolSUSkippedMajorVersionKey];
}

int getMajorVersion(NSString *version) {
    
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
    ///     -> This allows users to stay on their current major version, and still receive minor updates.
    ///     -> Sparkle 2 has a similar feature built in I think (They have a `SUSkippedMajorVersionKey`). We sort of re-implemented this here on Sparkle 1. Seemed easier and less risky to reimplement it instead of upgrading to Sparkle 2, but I'm not sure.
    /// - 1. For minor updates, we present the user with the newest available update (standard)
    /// - 2. but for major updates, we always present the user with the *oldest* available major update
    ///     - That's so the user sees the x.0.0 update notes with all the major changes.
    ///     - This is especially nice, if the new major version is a paid update, but it's always kind of nice to give the user an intro to the new major version I think.
    ///     - This also makes it so the user only has to skip one major update to stay on the current major version. E.g. if you're on 2.2.1, the only major update you will ever be presented with is 3.0.0 - the oldest major update. If you then skip 3.0.0, you won't see any other major updates, such as 3.0.2, or 4.0.0.
    ///     - A side effect of this is that we don't ever jump over major versions. If we're on 0.9, we will be presented with 1.0 next. Then if we're on 1.0, we'll be presented with 2.0 next. We don't skip past major versions.
    ///         - This might be very useful in a case where the 3.0.0 update notes explain that MMF 3+ are monetized, but the MMF 4 update notes don't re-explain that MMF 3+ are monetized. If we don't allow MMF 2 users to go straight to MMF 4, they won't be able to miss the info that MMF 3+ are monetized.
    /// - 3. xxx If there's a free update, we prioritize that.
    ///     - E.g. MMF 2.2.5 -> 2.2.6 will be presented over 2.2.5 -> 3.0.0 --- because MMF 2 -> MMF 3 is a paid update.
    ///     -> We removed this, because the features we implemented so users can stay on the current major version and still receive updates, solve the same issue as this I think.
    ///     - Note from old implementation: I think it's better without this, since even without this, the user will be prompted to update to next major version. And if they skip it, they will instead see minor version updates. That's good enough and consistent, and we won't have to have some up-to-date database about which updates are free/paid.

    /// Discussion:
    /// - Discussion/brainstorming for custom logic: https://github.com/noah-nuebling/mac-mouse-fix/issues/962#issuecomment-2120238813
    /// - As far as I understand, the `appcast` arg is already prefiltered by Sparkle using stuff like skippedUpdates, minimumAutoupdateVersion and minimumOSVersion.
    ///   Also, as far as I understand, the default implementation of this method simply uses [delegate versionComparator] (which defaults to a `SUStandardVersionComparator`) to get the appCast item with the highest version.
    ///     - I base these assumptions the following Sparkle 2 source code (we're using Sparkle 1.26.0 at the time of writing, but I hope nothing drastic changed): https://github.com/sparkle-project/Sparkle/blob/2247105ff37ba7b317e65af9833ecbb0f67f81de/Sparkle/SUAppcastDriver.m#L230
    ///     - **Update**: Things do seem to be different that what I assumed: The `appcast` arg is not prefiltered. Instead it seems like the SUAppCastItem *returned* by this method is checked by Sparkle against skippedUpdates, minimumAutoupdateVersion, etc.  to decide whether to actually present it.
    /// - Tip for testing: You can test this pretty well by just changing the build number and version in Xcode and then building the app and seeing which updates it shows you.
    ///
    /// Random/not important:
    /// - It might be slightly nice to delete the users' choice about skipping major versions when a new major version of the app is launched for the first time.
    ///     - Otherwise, there could be some slighlyyy inconsistent behavior where: You're on 2.0.0. You skip the 2.2.3 minor update. Then you update to 3.0.0, and then you skip the 3.0.2 minor update. Then you downgrade to 2.0.0. Your choice about skipping the 2.2.3 update has been deleted, and you're presented with 2.2.3 update a second time. This isn't bad in itself. But here's the inconsistency: If you didn't skip any minor updates while you were on MMF 3, then your choice about skipping the 2.2.3 update wouldn't have been deleted, and you wouldn't have been presented the 2.2.3 update a second time after downgrading to MMF 2.0.0. That's sort of strange. But I don't think it matters.
    ///     - 'Fixing' this this would require us to introduce a new `launchesOfCurrentMajorVersion` variable in AppDelegate, analogous to the `launchesOfCurrentBundleVersion` variable. But I don't think it's worth it.
    /// - The original design for our`bestValidUpdateInAppcast:` logic (which I more or less outlined [here](https://github.com/noah-nuebling/mac-mouse-fix/issues/962#issuecomment-2120238813) and which was implemented in older commits) was implemented in a more complicated way, but should behave mostly the same. The problems that made me think of this new solution, and which this new solution fixes is this:
    ///     1. In the old implementation, if you skipped a minor version, and then downgraded to a previous major version, you would't receive any minor updates. That's because if you skipped a minor update, all updates with a lower build number would not be presented to the user anymore.
    ///     2. If you skipped a major update, and then manually downloaded a new major version, then that new major version also wouldn't present any major updates to itself to the user. That's because we only used to store a piece of state saying userDidSkipAMajorUpdate, with no way to differentiate, which major update was skipped.
    ///     -> I won't explain the details, but this new implementation - aside from being easier to read - should fix both of these issues.
    
    /// Retrieve skipped versions
    NSInteger skippedMinorUpdate = [NSUserDefaults.standardUserDefaults integerForKey:CoolSUSkippedMinorVersionKey];
    NSInteger skippedMajorUpdate = [NSUserDefaults.standardUserDefaults integerForKey:CoolSUSkippedMajorVersionKey];
    
    /// Extract updates
    NSArray <SUAppcastItem *> *updates = appcast.items;
    
    /// DEBUG: Shuffle updates
    ///     -> So that we can see if the algorithm really works reliably
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
    
    /// Extract current version
    NSString *currentVersion = Locator.bundleVersionShort;
    int currentMajorVersion = getMajorVersion(currentVersion);
    NSInteger currentBuildNumber = Locator.bundleVersion;
    
    /// Create comparator
    ///  Note: We're using a cool custom comparator which considers `2.0.0` and `2.0.0 Beta 5` to be the same version, because it only looks at the `2.0.0` part.
    CoolSUComparator *comparator = [[CoolSUComparator alloc] init];
    
    /// Preprocess list of updates
    NSMutableArray <SUAppcastItem *> *minorUpdates = [NSMutableArray array];
    NSMutableArray <SUAppcastItem *> *majorUpdates = [NSMutableArray array];
    SUAppcastItem *latestUnshowableUpdate = nil;
    
    for (SUAppcastItem *update in updates) {
        
        /// Extract versions
        NSInteger buildNumber = [update.versionString integerValue];
        NSString *version = update.displayVersionString;
        int majorVersion = getMajorVersion(version);
        
        /// Find latest update that Sparkle won't show
        ///     Note: In case we don't find an update that we want to present to the user, we want to return the newest update that Sparkle won't show to the user - That way Sparkle won't present an update prompt to the user,
        ///     - (if we return nil from this method, Sparkle just takes over control and just presents the latest version - I saw this under 1.26.0)
        ///     - We can return an empty appcast item to prevent Sparkle from presenting any update, but that will cause Sparkle to show a message saying `Mac Mouse Fix (null) is currently the newest version available` when you choose `Check for Updates...` from the menu bar.
        ///     - When we return the latest unshowable version, then Sparkle won't present an update to the user, *and* the mentioned dialog will not show (null). Instead it will show some valid version of the app.
        ///     -> Example scenario where this stuff matters: When we're already on the newest version and we choose `Check for Updates...` from the menu bar.
        
        if (currentBuildNumber >= buildNumber) { /// If the user has a higher or equal build number to the `update`, then Sparkle won't show the `update`.
            
            if (latestUnshowableUpdate == nil) { /// Init latestUnshowableUpdate
                latestUnshowableUpdate = update;
            } else { /// Update latestUnshowableUpdate to be the latest it can be
                BOOL isLater = [comparator compareVersion:version withBuildNumber:@(buildNumber)
                                                toVersion:latestUnshowableUpdate.displayVersionString withBuildNumber:latestUnshowableUpdate.versionString] == NSOrderedDescending;
                if (isLater) {
                    latestUnshowableUpdate = update;
                }
            }
            
        }
        
        /// Filter out old updates
        ///     Notes:
        ///     - I thought Sparkle would already filter older versions out before passing the appcast to this method, but apparently not.
        ///     - I think I based this assumption on reading the Sparkle 2 source code. Maybe it's different here since we're on Sparkle 1
        ///     - I think if we return an update for which Sparkle determines that it's invalid due to skippedUpdates, minimumAutoupdateVersion and minimumOSVersion, then Sparkle will just not display the update we return. But not sure. Update: Seems to be true based on my tests.
        if ([comparator compareVersion:currentVersion withBuildNumber:@(currentBuildNumber) 
                             toVersion:version withBuildNumber:@(buildNumber)] != NSOrderedAscending) {
            
            /// Log
            DDLogDebug(@"UPDATER: Found OUTDATED update: %@ (%ld)", version, buildNumber);
            
            /// Skip to next update
            continue;
        }
        
        /// Split the updates into minorUpdates and majorUpdates
        
        if (majorVersion == currentMajorVersion) {
            
            /// Log
            DDLogDebug(@"UPDATER: Found MINOR update: %@ (%ld)", version, buildNumber);

            /// Store update
            [minorUpdates addObject:update];
            
        } else if (majorVersion > currentMajorVersion) {
            
            /// Log
            DDLogDebug(@"UPDATER: Found MAJOR update: %@ (%ld)", version, buildNumber);
            
            /// Store update
            [majorUpdates addObject:update];
            
        } else {
            assert(false); /// This should be filtered out
        }
    }
    
    /// Find the best update among the minor updates
    
    SUAppcastItem *bestMinorUpdate = nil;
    for (SUAppcastItem *minorUpdate in minorUpdates) {
        
        /// Init
        if (bestMinorUpdate == nil) {
            bestMinorUpdate = minorUpdate;
            continue;
        }
        
        /// We just find the latest update
        if ([comparator compareVersion:bestMinorUpdate.displayVersionString withBuildNumber:bestMinorUpdate.versionString
                             toVersion:minorUpdate.displayVersionString withBuildNumber:minorUpdate.versionString] == NSOrderedAscending) {
            
            bestMinorUpdate = minorUpdate;
        }
    }
    
    /// Find the best update among the major updates
    
    SUAppcastItem *bestMajorUpdate = nil;
    for (SUAppcastItem *majorUpdate in majorUpdates) {
        
        /// Init
        if (bestMajorUpdate == nil) {
            bestMajorUpdate = majorUpdate;
            continue;
        }
        
        /// We want the update with the lowest version number. So e.g. `3.0.0` is better than `3.0.2`
        NSComparisonResult comparisonResult = [comparator compareVersion:bestMajorUpdate.displayVersionString toVersion:majorUpdate.displayVersionString];
        if (comparisonResult == NSOrderedDescending) {
            bestMajorUpdate = majorUpdate;
            continue;
        } else if (comparisonResult == NSOrderedAscending) {
            continue;
        }
        
        /// Between two updates with the same version number - e.g. `3.0.0` vs `3.0.0 Beta 2`, we want the update with the highest build number.
        ///  Note: This logic is only possible because of our custom `CoolSUComparator` which considers `2.0.0` and `2.0.0 Beta 5` to be the same version unlike the default Sparkle 1 comparator.
        BOOL hasHigherBuildNumber = [bestMajorUpdate.versionString integerValue] < [majorUpdate.versionString integerValue];
        if (hasHigherBuildNumber) {
            bestMajorUpdate = majorUpdate;
            continue;
        }
    }
    
    /// Log
    DDLogInfo(@"UPDATER: bestMajorUpdate: %@ (%@), bestMinorUpdate: %@ (%@), latestUnshowableUpdate: %@ (%@),\ncurrentVersion: %@ (%ld),\nskippedMajorUpdate %ld, skippedMinorUpdate %ld", bestMajorUpdate.displayVersionString, bestMajorUpdate.versionString, bestMinorUpdate.displayVersionString, bestMinorUpdate.versionString, latestUnshowableUpdate.displayVersionString, latestUnshowableUpdate.versionString, currentVersion, currentBuildNumber, skippedMajorUpdate, skippedMinorUpdate);
    
    /// Respect skipped versions
    if ([bestMinorUpdate.versionString integerValue] == skippedMinorUpdate) {
        bestMinorUpdate = nil;
    }
    if ([bestMajorUpdate.versionString integerValue] == skippedMajorUpdate) {
        bestMajorUpdate = nil;
    }
    
    /// Delete the skipped version that Sparkle stores
    ///     Note: This should prevent an **obscure edge case**, which is explained in the other place where where we delete `SUSkippedMinorVersionKey`.
    [NSUserDefaults.standardUserDefaults removeObjectForKey:SUSkippedMinorVersionKey];
    
    /// Return an update
    if (bestMajorUpdate != nil) {
        return bestMajorUpdate;
    } else if (bestMinorUpdate != nil) {
        /// Note that, in case there's a major *and* a minor update, only the major update will be displayed. But if the user skips the major update, the app will immediately check for upates again and then present the minor update.
        return bestMinorUpdate;
    } else if (latestUnshowableUpdate != nil) {
        return latestUnshowableUpdate;  /// Newest update which Sparkle (1.26.0) won't present to the user. Explanation where this variable is filled.
    } else {
        DDLogInfo(@"UPDATER: WARN: Returning empty appcastItem to Sparkle because we couldn't find a latestUnshowableUpdate. This normally shouldn't happen I think, except if the build number of this build is very low.");
        return [[SUAppcastItem alloc] init];    /// If we return nil, Sparkle (1.26.0) will just show the latest udpate to the user which we want to avoid.
    }
}

- (void)updater:(SUUpdater *)updater userDidSkipThisVersion:(SUAppcastItem *)item {
    
    DDLogInfo(@"UPDATER: User skipped version %@", item.displayVersionString);
    
    int skippedMajorVersion = getMajorVersion(item.displayVersionString);
    int currentMajorVersion = getMajorVersion(Locator.bundleVersionShort);
    
    BOOL isMajorUpdate = skippedMajorVersion > currentMajorVersion;
    
    if (isMajorUpdate) {
        [NSUserDefaults.standardUserDefaults setInteger:[item.versionString integerValue] forKey:CoolSUSkippedMajorVersionKey];
    } else {
        [NSUserDefaults.standardUserDefaults setInteger:[item.versionString integerValue] forKey:CoolSUSkippedMinorVersionKey];
    }
    
    /// Do stuff after delay
    /// Note:
    /// - Not sure what the delay should be. Did zero testing. 1.0 is probably much higher than necessary, but seems to work alright.
    /// - The optimal delay for the diffent stuff we do here might also be different. But it works ok.
    /// - Update: Changed delay to 0.0, for snappier ux. Still works perfect. I think we just need to dispatch to `main_queue` so this stuff happens on the next runLoop iteration or sth.
    
    float delayInSeconds = 0.0;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        /// Prevent Sparkle from storing its own skippedVersion
        ///     By deleting the default Sparkle key from user defaults.
        ///
        /// Notes:
        /// - If we ever switch to Sparkle 2, we might want to remove Sparkles' MajorVersionKey as well as the MinorVersionKey.
        /// - Also, under Sparkle 2, I think the skipped versions are filtered out before they are passed to `bestValidUpdateInAppcast:`, so we'd have to change the whole logic anyways.
        ///
        /// - There's an **obscure edge case** with this: (Never saw this, just speculating)
        ///     - It seems that Sparkle ignores all updates with a `buildNumber <= SUSkippedMinorVersionKey`. So therefore if we skip a minor version (and don't prevent Sparkle from storing that) and then downgrade to a previous major version, that would prevent all minor updates to this this lower major version. Any upates that `bestValidUpdateInAppcast:` returns would then just be ignored by Sparkle.
        ///     -> This edge case seems very unlikely now that I think about it, but there's always going to be someone among thousands of users. We could address this by instead deleting Sparkle's skipped version inside `bestValidUpdateInAppcast:`. But if we don't delete the skipped version right here, there would be other similar edge cases I think. So I guess the most robust would be to do it in both places. -> That's what we did.
        ///     - src: (Sparkle 1 src code)  https://github.com/sparkle-project/Sparkle/blob/10d96f2b9b9905b0f529f09e517219d4e20125c0/Sparkle/SUBasicUpdateDriver.m#L239.
        
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

    DDLogInfo(@"UPDATER: About to install update");
    
//    [MoreSheet.instance end]; // Close more sheet so it doesn't block popup

}

- (void)updaterDidRelaunchApplication:(SUUpdater *)updater {
    
    DDLogInfo(@"UPDATER: App has been launched by Sparkle Updater");
    
    /// Log the fact that updater launched the application in appState()
    ///     We use this from `AppDelegate - applicationDidFinishLaunching`.
    appState().updaterDidRelaunchApplication = YES;
    
    /// Kill helper
    /// It might be more robust and simple to find and kill any strange helpers *whenever* the app starts, but this should work, too.
    [HelperServices killAllHelpers];
    
}

@end
