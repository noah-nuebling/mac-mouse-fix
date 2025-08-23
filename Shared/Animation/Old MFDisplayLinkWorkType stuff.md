
[Aug 23 2025] Below is a backup of 
    - The `DisplayLink.m > displayLinkCallback()` function, before we're deleting it and rewriting it.
    - The `DisplayLink.m > mapInSharedMemoryForDisplay:` method and its helper function, which never worked IIRC.
    
    The backup of `displayLinkCallback()` contains tons of comments and dead code mostly (exclusively?) around the MFDisplayLinkWorkType stuff we shipped in 3.0.2. 
    IIRC, we disabled the MFDisplayLinkWorkType stuff in 3.0.3, but were then still left with a lot of comments and dead code.
    I've now decided to remove this all from the function, because I want to call `dispatch_sync()` immediately upon entering the function but this becomes difficult due to all the clutter. 
        The reason I want to call `dispatch_sync()` immediately: [Aug 2025]
            I got a report about a deadlock which I think can be made less likely by calling `dispatch_sync()` immediately. We also called `dispatch_sync()` immediately in 3.0.0 and 3.0.1 (before we changed things in 3.0.2)
                (See comment below: `Deadlock: [Aug 2025]` )

    Also see these Radars related to the MFDisplayLinkWorkType stuff:
        - FB13682243 - "Scheduling of CVDisplayLinkCallback causes stuttery scrolling throughout macOS"
        - FB19025288 - "Random Super-Slow and Super-Fast Trackpad Scrolls on macOS Tahoe"
            > Here we talk about how FB13682243 seems to be fixed under Tahoe (yay) (See "idle prefetch" in the 2025 State of the Union) but how that may be causing issues with momentum-scrolling. 

# `displayLinkCallback()` function

    static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext) {
        
        /// Get self
        DisplayLink *self = (__bridge DisplayLink *)displayLinkContext;
        
        /// Parse timestamps
        DisplayLinkCallbackTimeInfo timeInfo = parseTimeStamps(inNow, inOutputTime);
        
        /// Debug
        DDLogDebug(@"DisplayLink.m: (%@) Callback", [self identifier]);
        
        /// Define workload
        __auto_type workload = ^void (DisplayLinkCallbackTimeInfo timeInfo) {
            
            /// Check requestedState
            if (self->_requestedState == kMFDisplayLinkRequestedStateStopped) {
                DDLogDebug(@"DisplayLink.m: (%@) callback called after requested stop. Returning", [self identifier]);
                return;
            }
            
            /// Call block
            self.callback(timeInfo);
                    
        };
        
        if (self->_optimizedWorkType == kMFDisplayLinkWorkTypeGraphicsRendering) {
            
            /// Notes:
            /// - For workType graphicsRendering we do the workload immediately. So we keep the scheduling from CVDisplayLink. CVDisplayLink seems to be designed for drawing graphics, so this should make sense.
            ///     - Actually, thinking about this a bit, I feel like our graphics animations that are driven by DisplayLink (at time of writing just the DynamicSystemAnimator.swift stuff) might also reduce framedrops by scheduling them differently. Evidence: We're currently articially slowing down DynamicSystemAnimator by making the sampleRate super high because for some reason that lead to much smoother framerates. This smells like better scheduling could improve things.
            ///     - The new CADisplayLink framework which was ported from iOS to macOS might have better scheduling?
            ///     - TODO: See if different scheduling can improve animation performance.
            /// - Use dispatch_sync so this is actually executed immediately on the high-priority display-linked thread - not sure if this is necessary or helpful in any way.
            /// - Why are we using `self.dispatchQueue` instead of `self->_displayLinkQueue`? I think self.dispatchQueue might cause some weird timing stuff since self.dispatchQueue is atomic.
            ///
            
            dispatch_sync(self.dispatchQueue, ^{
                workload(timeInfo);
            });
            
        } else if (self->_optimizedWorkType == kMFDisplayLinkWorkTypeEventSending) {
            
            /// Deadlock: [Aug 2025] There's a deadlock here which causes smooth-scrolling to stop working.
            {
                ///     Context: We thought we fixed the `Scroll Stops Working Intermittently` bug in 3.0.6 by handling when `CVDisplayLinkCreateWithActiveCGDisplays()` fails (maybe that did fix some instances)
                ///             But Joonas sent an email (`message:<9A015C69-0B52-407B-BA91-FDB35D527B6B@gmail.com>`) with a sample that clearly contains a **deadlock**.
                ///     The deadlock happens because:
                ///         - The thread running `displayLinkCallback()` acquires the private __CVDisplayLink lock first__, and then tries to `dispatch_sync` to our queue.
                ///         - The thread running `Scroll.m > [_animator startWithParams: ...]` (And I think all other places interacting with the CVDisplayLink) acquires the __queue first__, and then acquires the private CVDisplayLink lock
                ///             (implicitly by calling `CVDisplayLinkSetCurrentCGDisplay()` – I assume all interactions with the CVDisplayLink implicitly acquire the private lock)
                ///         -> If one thread has lock A and the other thread has lock B, and they both wait on the other's lock – there's a deadlock.
                ///     Ways to deal with the deadlock:
                ///         1. Minimize the time that is spent inside displayLinkCallback before it dispatches to the queue.
                ///             - This could minimize the bug but probably not entirely eliminate it.
                ///             - Changes in timing may introduce new bugs
                ///             -> TODO: To decide how/if to change the code – Look at how older MMF versions like 3.0.0 did things and when the `Scroll Stops Working Intermittently` bug started (we wrote about that in the MOS issue IIRC)
                ///         2. Use `dispatch_async` instead of `dispatch_sync` inside the displayLinkCallback
                ///             - Pro: Would solve the deadlock and I believe is close to how things would work with CADisplayLink – so I think performance isn't inherently bad – even if our workload doesn't execute on the special "high priority" displayLink thread. (Similarity to CADisplayLink is also interesting since we may want to transition to that eventually)
                ///             - Contra: Changes the scheduling a lot and could cause or surface new bugs.
                ///                 IIRC, during the MMF versions where we shipped the MFDisplayLinkWorkType stuff, there were strange bugs that I never understood (was it crashes?) – and I thought they might have been caused by these kinds of scheduling differences?
                ///         3. Replace `dispatch_sync` with a custom recreation of `dispatch_sync` that can time out.
                ///             - Pro: Should allow us to keep exactly the same scheduling, with a precise fix for the deadlock (The timeout)
                ///             - Contra: Could degrade performance due to slightly more CPU work, and switching to another thread which may be 'lower priority'.
                ///             - Contra: Frequent timeouts could lead to hangs and 'dropped scrolling frames'. (Still an improvement)
                ///         4. Make the lock-acquisition order consistent:
                ///             - Pro: Would completely eliminate the deadlock, and solve it in a 'theoretically correct' way.
                ///             - Contra: Requires extracting the private lock from CVDisplayLink via reverse engineering (shouldn't be too bad – but we'd have to test that this works on all macOS versions we support, since this is CPP and we'd have to hardcode memory offsets I think.)
                ///             - 2 Possible approaches:
                ///                 4.1. Make it so the __queue lock is always acquired first__
                ///                     Contra: Technically infeasible – would have to modify the CVDisplayLink code so that it acquires our queue lock before it acquires its private lock in preparation for calling `displayLinkCallback()`
                ///                 4.2. Make it so the __CVDisplayLink lock is always acquired first__
                ///                     Contra: Would require us to always lock the private lock before we dispatch to our queue. Not sure if this would cause new bugs. Not sure if it's ok to lock/unlock mutexes from different threads (which I think we'd have to do)
                ///     TODO: [Aug 2025]
                ///         - [ ] Look into shipping a hotfix / hot-improvement – 1. and 3. seem promising for a hotfix. 2. seems most promising for the long-term (with the CADisplayLink transition)
            }
            
            
            /// Notes:
            /// - For workType eventSending, we execute the workload at the start of the next frame instead of right before the nextFrame. We hope that this will reduce stuttering in Safari and other apps.
            /// - From my understanding, timeInfo.thisFrame is in vsyncTime aka videoTime, and the dispatch_after call is in hostTime aka machTime. When the two time scales are out of sync, then that might lead to problems. I think you can sync them with rateScalar somehow, but not sure how that works.
            ///     - More on hostTime and videoTime/vsynctime in this litherium post on understanding CVDisplayLink: http://litherum.blogspot.com/2021/05/understanding-cvdisplaylink.html
            /// - I think dispatching at the start of the next frame helps performance. Sometimes on reddit it scrolls perfectly, but then sometimes it will get stuttery again. While the trackpad still scrolls smoothly. Not sure what's going on.
            /// - To get the time of the next frame for dispatch_after we should just be able to use `secondsToMachTime(timeInfo.nextFrame + nextFrameOffset);`, but I did a tiny bit of testing and there were some problems iirc. Either way the method we use now with dispatch_time is accurate and works well so it doesn't matter.
            /// - On this website --- https://mindofastoic.com/stoic-quotes?utm_content=cmp-true --- I can get pretty consistent framedrops
            ///
            /// Investigation into scrolling framedrops
            ///     (This investigation lead to the creation of the code for kMFDisplayLinkWorkTypeEventSending)
            /// - Results:
            ///     - The workload (so the actual stuff MMF is doing) takes less than 1 ms, so it can't be the source of the frame drops.
            ///     - It seems the callback is called ca. 4 ms before the next outFrame. This is really late. Maybe if our callback was called earlier in the 16.66ms period between frames we could avoid the framedrops
            ///
            /// - Other notes:
            ///     - See this Hacker News post on CVDisplayLink not actually syncing to your display: https://news.ycombinator.com/item?id=15889549
            ///         - The linked article corrects most of the claims it makes in an update, but then in the correction still says that `CVDisplayLinkCreateWithActiveCGDisplays` creates a non-vsynced display link. Which doesn't make sense I think since you can still assign that displayLink a `currentDisplay` which it should then sync to.
            ///             - The article links to this article on CADisplayLink on iOS for game loops. The link is dead but I think this is a mirror: https://www.gamedeveloper.com/programming/game-loops-on-ios
            ///             - The correction of the article says that CADisplayLink gets the vsync times from the kernel via StdFBSmem_t. Usage example here: https://stackoverflow.com/questions/2433207/different-cursor-formats-in-ioframebuffershared
            ///     - Since macOS 14.0 there is also the CADisplayLink API which was previously only available on iOS. There should be more resources on how to get it to work properly, since it's an iOS api. I haven't tested it, could it have different scheduling that might help with framedrops?
            ///
            /// - Experiments with usleep
            ///     - If we sleep for 17ms inside our dispatch_sync callback, then the framerate drops to 30 fps as expected.
            ///     - If we sleep for 8ms everything seems to work the same - light websites like hacker news run perfectly smooth, but websites like reddit stutter
            ///         - (remember that the whole dispatch_sync callback usually only takes around 1 ms, not 8 - so our code being slow doesn't seem to be the reason for stuttering)
            ///     - Conclusion:
            ///         - Theory: The displayLink tries to schedule the call of this callback so that it's done right before the frame is rendered (in the hackernews post that was mentioned somewhere, also, IIRC, this aligns with our observations about how timeInfo.lastFrame relates to the time when the CVDisplayLinkCallback is called). This scheduling makes sense (I think?) if we're *drawing* from the displayLink callback - which is what the displayLink callback is designed for. However, we're not drawing - we're outputting scroll events. Safari then still has to draw stuff based on these scroll events during the same frame. Since the scroll events are sent very late in the frame, that gives Safari very little time to draw its updates based on the incoming scroll events. Possible solution to framedrops: Output the scroll events *early* in the frame instead of late.
            /// - Experiments with scheduling
            ///     - We tried call our self.callback right after the next frame using dispatch_after. (Instead of right before the frame, which seems to be the natural behaviour of CVDisplayLink)
            ///         - I used this new scheduling for a day - in Safari and Chrome, scrolling peformance seems to now be on par with Trackpad scroling. I'm not 100% sure it's not a placebo that it's working better than dispatch_sync which we were using before, but as I said it' on par with the trackpad, so I think it's close to as good as it gets. However, in Safari, with a real trackpad, the scrolling performance is still better during momentumPhase. My best theories are
            ///             1. Safari stops listening to input events during momentumPhase and just drives the animations itself - leading to better performance. I know Xcode and some other apps do this, but I thought Safari didn't?
            ///             2. The scheduling of events coming from the trackpad driver during momentumPhase is faster than the screen refreshRate or aligned with the screen refresh rate in a different way, leading to less stuttering somehow.
            ///                 - I tried sending double the amount of scroll events but it didn't help I think. That was in commit db15199233b8be30036696105a8435dc83fa3efa
            ///         - Note on dispatch_after: I was worried that using `dispatch_after` would have worse performance than executing directly on the 'high performance display link thread' which the CVDisplayLink callback apparently runs on. But this doesn't seem to matter. From my observations (didn't reproduce this several times, so not 100% sure), using `dispatch_after`, it looks like the code we dispatch to consistently finishes within 2 ms of the preceding frame (Or more than 14 ms before the next frame). Even when there is heavy scroll stuttering in Safari. So using `dispatch_after` should be more than accurate and fast enough, and the stuttering seems to be caused by scheduling issues/issues in Safari.
            ///
            /// - Update after 3.0.2 release
            ///     - See this GH Issue by V-Coba: https://github.com/noah-nuebling/mac-mouse-fix/issues/875
            ///     - These change from 3.0.2 didn't really help in Safari. Sometimes MMF is smooth and the trackpad stutters, but sometimes the trackpad stutters and MMF is smooth. In Firefox, these changes seem to have created additional stutters, and it was very smooth before. So our experiment was unsuccessful. (And we shouldn't have published it in a stable release)
            ///     - We created two alternative builds: 3.0.2-v-coba and 3.0.2-v-coba-2. The original 3.0.2 build's scheduling (right after a frame) made things noticably worse in Firefox, and I got several feedbacks that scrolling was more stuttery. The first `v-coba` build went back to the native schduling (right before the frame), and restored the original performance characteristics. The `v-coba-2` build tried alternative scheduling optimized to get the best perfromance for scrolling on Reddit in Safari on my M1 MBA. However, in some situations, I observed it having more stutters on light websites like GitHub.
            ///         - Overall, I'm not sure which of the builds is better on average, they all stutter at times. But the original scheduling at least seemed to be stutter free on Firefox. While the 3.0.2 scheduling is not stutter free on Firefox anymore. For the `v-coba-2` scheduling, I haven't tested how it works with Firefox.
            ///         -> I think for now, **it's best to go back to the original scheduling**, since I'm confident that it's good on Firefox, and I'm not confident in the benefits of the 2 other schedulings we tried.
            ///             - See this comment for further discussion of this decisin: https://github.com/noah-nuebling/mac-mouse-fix/issues/875#issuecomment-2016869451
            ///         -> Maybe later, we can explore trying to analyze the CVDisplayLinkThread of the scrolled app in order to improve scheduling. That's the best idea I have right now. See https://github.com/noah-nuebling/mac-mouse-fix/issues/875#issuecomment-1986811798 for more info and potential libraries we could use to achieve this.

            
            /// Get timestamp for start of callback
            CFTimeInterval startTs = CACurrentMediaTime();
            
            /// Declare debug vars
            static CFTimeInterval rts;
            __block CFTimeInterval startTsSync;
            __block CFTimeInterval endTsSync;
            static CFTimeInterval lastEndTsSync;
            
            /// Add debug logging to workload
            
            if (runningPreRelease()) {
                
                workload = ^(DisplayLinkCallbackTimeInfo timeInfo){
                    
                    /// Debug
                    DDLogDebug(@"DisplayLink.m: (%@) Callback workload", [self identifier]);
                    startTsSync = CACurrentMediaTime();
                    
                    /// Do work
                    workload(timeInfo);
                    
                    /// Debug
                        
                    /// Get timestamp
                    endTsSync = CACurrentMediaTime();
                    
                    /// Get vsync info from shared memory
                    uint64_t vblCount = 0;
                    CFTimeInterval vblTime = 0.0;
                    CFTimeInterval vblDelta = 0.0;
                    if (self->_sharedMemoryIsMappedIn) {
                        vblCount = self->_currentDisplayFrameBufferSharedMemory->vblCount;
                        AbsoluteTime vblTimeWide = self->_currentDisplayFrameBufferSharedMemory->vblTime;
                        AbsoluteTime vblDeltaWide = self->_currentDisplayFrameBufferSharedMemory->vblDelta;
                        uint64_t vblTimeHost = (vblTimeWide.hi << 4) + vblTimeWide.lo;
                        uint64_t vblDeltaHost = (vblDeltaWide.hi << 4) + vblDeltaWide.lo;
                        vblTime = machTimeToSeconds(vblTimeHost);
                        vblDelta = machTimeToSeconds(vblDeltaHost);
                    }
                    
                    /// Print
                    DDLogDebug(@"DisplayLink.m: (%@) callback workload times - last %f, now %f, now2 %f, next %f, send %f\n|| overallProcessing %f, workProcessing %f, workPeriod %f, nextFrameToWorkCompletion %f\n||vblTime: %f, vblDelta: %f, vblCount: %llu",
                               [self identifier],
                               (timeInfo.lastFrame - rts) * 1000,
                               (timeInfo.cvCallbackTime - rts) * 1000,
                               (startTs - rts) * 1000,
                               (timeInfo.thisFrame - rts) * 1000,
                               (endTsSync - rts) * 1000,
                               
                               (endTsSync - startTs) * 1000,
                               (endTsSync - startTsSync) * 1000,
                               (endTsSync - lastEndTsSync) * 1000,
                               (endTsSync - timeInfo.thisFrame) * 1000,
                               
                               vblTime - rts,
                               vblDelta, vblCount);
                    
                    lastEndTsSync = endTsSync;
                    
                };
            }
            
            /// Calculate delay for doing workload
            ///
            /// Explanation:
            /// - The goal is that we do the workload at time `anchorTs + offset`
            ///
            /// Values to use:
            /// - Timestamps you might want to use for `anchorTs`: `timeInfo.lastFrame`, `timeInfo.nextFrame`, or `startTs`
            /// - Set `anchorTs` to -1 to do the work immediately (i.e use native CVDisplayLink scheduling)
            ///     - (`offset` should be set to 0 in this case)
            /// - `offset` can also be negative to do the workload before `anchorTs`.
            ///
            /// Values to recreate behavior of past versions:
            /// - Pre-3.0.2 + 3.0.2-v-coba behavior:
            ///     - anchorTs = -1, offset = 0
            /// - 3.0.2 behavior:
            ///     - anchorTs = timeInfo.nextFrame, offset = 0
            /// - 3.0.2-v-coba-2 behavior:
            ///     - anchorTs = `startTs`, offset = `3.75/16.0 * timeInfo.nominalTimeBetweenFrames`
            ///       (In the **Old experiments** you can find below, and in the `v-coba-2` source code, we wrote this offset as`-12.25/16.0 * timeInfo.nominalTimeBetweenFrames + timeInfo.nominalTimeBetweenFrames`)
            ///
            ///
            /// **Old experiments** that led us to the v-coba-2 behavior:
            ///
            /// **nextFrameOffset** testing in Safari:
            ///
            /// - 0.0 ok - 3.0.2 shipped with it
            /// - -0.2 better (??)
            /// - -0.4 worse (??) (This is basically same as native CVDisplayLink time rn)
            ///
            /// - 4ms+ gets noticably worse
            /// - 8ms+ gets better again
            /// - 12ms+ gets worse again (should be around same behaviour as -0.4 I think, since it's ca. nextNextFrameTime-0.4?)
            /// - 16.16ms+ is really bad
            ///
            /// **nextCallbackOffset** testing in Safari on Reddit frontpage.
            ///
            /// I think making things relative to the CVDisplayLinkCallbacks instead of frametimes might make more sense, since I looked into Firefox and Safari and they both also use CVDisplayLinkCallbacks for synchronization.
            ///
            /// - 14/16 idk
            /// - 12/16 ok. Worse than -12/16
            /// - 10/16 really bad
            /// - 8/16 worse
            /// - 6/16 idk
            /// - 4/16    **good**      feels the same as -12/16. Maybe little smoother, but since the delay is longer we prefer -12/16 over this
            /// - 2/16 idk
            ///
            /// - 0.0 baseline
            ///
            /// - -2/16 idk
            /// - -4/16 pretty good. Worse than -12/16. I think `-4/16 * 16.666` is worse than the approximation we used before -4.0;
            /// - -6/16 idk
            /// - -8/16 worse
            /// - -10/16 really bad
            /// - -11/16 worse than -12/16, better than -13/16 I think
            /// - -11.5/16 worse than -12/16
            /// - -11.75/16 same as -12/16
            /// - -11.9/16 same as -12/16
            /// - -12/16 **good**
            /// - -12.1/16 same as -12/16
            /// - -12.2/16 same as 12.25/16 I think
            /// - -12.25/16 might be **better** than -12/16                     -> we ended up using this for the **3.0.2-v-coba-2** build
            /// - -12.3/16 maybe worse than 12.25/16
            /// - -12.4/16 I think worse than 12.25
            /// - -12.5/16 I think worse than -12.25/16
            /// - -13/16 noticably worse than -12/16
            /// - -14/16 not great
            
            CFTimeInterval anchorTs = -1;   //startTs;
            CFTimeInterval offset   = 0;    //3.75/16.0 * timeInfo.nominalTimeBetweenFrames;
            
            CFTimeInterval workTs = anchorTs + offset;
            CFTimeInterval workDelay = workTs - startTs;
            
            if (anchorTs == -1) {
                assert(offset == 0);
            }
            if (workDelay <= 0) {
                assert(anchorTs == -1); /// If there's no delay, then we should have explicitly turned that off by setting anchorTs = -1
            }
            
            /// 
            /// Do workload
            ///
            
            if (workDelay <= 0) {
                dispatch_sync(self.dispatchQueue, ^{ /// Classic way of scheduling the workload
                    workload(timeInfo);
                });
            } else {
                DDLogError(@"DisplayLink.m: (%@) Don't use special scheduling without extensive testing. This caused regressions in scrolling stutteriness in some scenarios and even crashes I think (See 3.0.2-vcoba stuff: https://github.com/noah-nuebling/mac-mouse-fix/issues/875, and 3.0.2 crashes: https://github.com/noah-nuebling/mac-mouse-fix/issues/988)", [self identifier]);
                assert(false);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC*workDelay), self->_displayLinkQueue, ^{ /// Schedule the workload to run after `workDelay`
                    workload(timeInfo);
                });
            }
            
        } else { /// if `self->_optimizedWorkType` is unknown
            assert(false);
        }
        
        /// Return
        return kCVReturnSuccess;
    }

# Shared memory methods

    vvv [Aug 2025] Old methods from `DisplayLink.m` for getting the vsync times from a lower-level `FrameBuffer` APIs. IIRC this never worked. (IIRC I only tested on Apple Silicon)

    - (CVReturn)mapInSharedMemoryForDisplay:(CGDirectDisplayID)displayID {
        
        assert(false);
        
        ///
        /// Map in shared memory from kernel
        ///     To get vsync timestamps directly form kernel to see if cvdisplaylink timestamps align with that
        ///
        /// Notes:
        /// - This code is copied from: https://stackoverflow.com/q/2433207/10601702
        /// - In the article from the ycombinator post on how cvdisplaylink doesn't actually sync to the display, there is a mention that CVDisplayLink itself gets the vsync times from shared memory (aka shmem) with the kernel in form of the publicly documented `StdFBShmem_t` struct. From my research you used to be able to map `StdFBShmem_t` into your processes memory through a series of steps building on`CGDisplayIOServicePort()`, which was then deprecated but replaced by the private `IOServicePortFromCGDisplayID()`, which was then removed but people replaced with a custom implementation using `IOServiceMatching("IODisplayConnect")`, which stopped working on Apple Silicon Macs. All these methods gave you access to an IODisplay instance and a 'FrameBuffer' which underlies the IODisplay as far as I understand. I think there also used to be `IOServiceMatching("IOFramebuffer")` but this seems to have been replaced by `IOServiceMatching("IOMobileFramebuffer")` on Apple Silicon Macs. There's a private set of functions to interact with it in the .tbd file of `MacOSX.sdk/System/Library/PrivateFrameworks/IOMobileFramebuffer.framework`. The most relevant function I could see was `_IOMobileFramebufferEnableVSyncNotifications` which has some documentation at https://iphonedev.wiki/IOMobileFramebuffer . Displays show up in the registry as objects of class `AppleCLCD2`, they have a bunch of attributes prefixed with `IOMFB` which seem to relate to the MobileFrameBuffer. I've also seen the prefix `IOFB`, which likely is an earlier prefix for the framebuffer, before it became the 'mobileFrameBuffer'. I assume that the `MobileFrameBuffer` APIs have been ported to macOS from iOS for the Apple Silicon transition. That would explain the `Mobile` prefix and the fact those APIs also seem to be present on iOS and seem to only exist on Apple Silicon Macs.
        ///
        /// Conclusion:
        /// - So far I haven't found a way to access the framebuffer stuff directly. It might be possible with private APIs, even on M1 Macs running the latest macOS version, but it's probably quite difficult.
        ///     - I'm pretty sure I have not found a way to access the framebuffer but I'm not 100% sure. It's been over a month between writing the code and writing these comments. Also see this GitHub comment I wrote as evidence that I haven't found a way: https://github.com/noah-nuebling/mac-mouse-fix/issues/875#issuecomment-1986394616
        /// - Accessing the framebuffer directly to get the vsync times would only help us if the timestamps that the CVDisplayLinkCallback receives from the system are not already giving us the correct vsync times. AND if, on top of that, bad syncing between our CGEvent-sending and the monitors' vsync is even the factor that causes the stuttering in the first place.
        ///     - From my observations, I lean towards thinking that these 2 factors are not the cause of the stuttering. Instead, I think that the problem is more likely bad syncing between the invocation time of the CVDisplayLinkCallbacks inside scrolled apps like Safari, with the send-time of the scroll events from MMF. I explain this theory more in this GitHub comment: https://github.com/noah-nuebling/mac-mouse-fix/issues/875#issuecomment-1986797450
        /// -> So since accessing the framebuffer is hard and I don't expect it to help us, **we gave up on trying to access the framebuffer**. Instead we planned to use system APIs to try and understand how the CVDisplayLinkCallback invocations are scheduled inside the scrolled app (like Safari), and to then schedule our event-sending relative to that. See this GitHub comment for more info: https://github.com/noah-nuebling/mac-mouse-fix/issues/875#issuecomment-1986811798
        
        ///
        /// Open IOService for this displays framebuffer
        ///
        
        /// Get framebuffer iterator
        /// Note:
        /// - Getting IOServiceGetMatchingService*s* and iterating over them probably makes more sense? But couldn't get that to work in short experiments.
        IOReturn ioErr;
        io_iterator_t iter;
        CFDictionaryRef frameBufferServiceMatching = IOServiceMatching("IOMobileFramebuffer"); /// MobileFrameBuffer is an Apple Silicon thing I think, see https://stackoverflow.com/questions/66812863/mac-m1-get-iomobileframebufferuserclient-interface
        io_service_t frameBufferService = IOServiceGetMatchingService(kIOMasterPortDefault, frameBufferServiceMatching);

        
        //    if (ioErr) {
    //        assert(false);
    //    }
        
        /// Iterate framebuffers
    //    io_service_t frameBufferService = IO_OBJECT_NULL;
    //    while (true) {
    //        if (frameBufferService != IO_OBJECT_NULL) assert(false); /// There are multiple framebuffers
    //        frameBufferService = IOIteratorNext(iter);
    //        if (frameBufferService != IO_OBJECT_NULL) break;
    //    }
        
        /// Validate
        assert(frameBufferService != IO_OBJECT_NULL);
        
        /// Retain framebuffer
        ///     Not sure if this leaks
    //    IOObjectRetain(frameBufferService);
        
        /// Release iterator
    //    IOObjectRelease(iter);
        
        
        
    //    io_service_t displayService = IOServicePortFromCGDisplayID(displayID); // CGDisplayIOServicePort(displayID);
    //    assert(displayService != 0);
        
        io_connect_t frameBufferConnect;
        ioErr = IOFramebufferOpen(frameBufferService, mach_task_self(), kIOFBSharedConnectType, &frameBufferConnect);
        
        ///
        /// Map shared memory
        ///
        
        if (ioErr == KERN_SUCCESS) {
                
            /// Unmap old memory
            ioErr = IOConnectUnmapMemory(frameBufferConnect, kIOFBCursorMemory, mach_task_self(), &_currentDisplayFrameBufferSharedMemory);
            if (ioErr) {
                assert(false);
            }
            
            /// Map new memory
            ///
            mach_vm_size_t size;
            IOConnectMapMemory(frameBufferConnect, kIOFBCursorMemory, mach_task_self(), &_currentDisplayFrameBufferSharedMemory, &size, /*kIOMapAnywhere +*/ kIOMapDefaultCache + kIOMapReadOnly);
            
            if (ioErr == KERN_SUCCESS) {
                assert(size == sizeof(StdFBShmem_t));
                
                AbsoluteTime vsyncTime = _currentDisplayFrameBufferSharedMemory->vblTime;
                DDLogDebug(@"DisplayLink.m: Created framebuffer for new display with vsyncTime: vsyncTime: %u, %u", vsyncTime.hi, vsyncTime.lo);
                
            } else {
                assert(false);
            }
        } else {
            assert(false);
        }
        
        /// Cleanup
        IOServiceClose(frameBufferConnect);
        
        /// Set flag
        ///     NOTE: At the time of writing, we're not unsetting this flag anywhere, which we should do e.g. if a display is disconnected.
        _sharedMemoryIsMappedIn = YES;
        
        /// Return
        return kCVReturnSuccess;
    }

    static io_service_t IOServicePortFromCGDisplayID(CGDirectDisplayID displayID) {
        
        assert(false);
        
        /// - Helper function for `mapInSharedMemoryForDisplay:`
        /// - copied from here: https://github.com/glfw/glfw/blob/e0a6772e5e4c672179fc69a90bcda3369792ed1f/src/cocoa_monitor.m
        /// - UPDATE: IOServiceMatching("IODisplayConnect") is not supported on apple silicon macs: https://developer.apple.com/forums/thread/666383
        ///
        /// Original comments:
        ///     Returns the `io_service_t` corresponding to a CG display ID, or 0 on failure.
        ///     The `io_service_t` should be released with IOObjectRelease when not needed
        
        io_iterator_t iter;
        io_service_t serv, servicePort = 0;
        
        CFMutableDictionaryRef matching = IOServiceMatching("IODisplayConnect");
        
        // releases matching for us
        kern_return_t err = IOServiceGetMatchingServices(kIOMasterPortDefault,
                                                         matching,
                                                         &iter);
        if (err)
            return 0;
        
        while ((serv = IOIteratorNext(iter)) != 0)
        {
            CFDictionaryRef info;
            CFIndex vendorID, productID, serialNumber;
            CFNumberRef vendorIDRef, productIDRef, serialNumberRef;
            Boolean success;
            
            info = IODisplayCreateInfoDictionary(serv,
                                                 kIODisplayOnlyPreferredName);
            
            vendorIDRef = CFDictionaryGetValue(info,
                                               CFSTR(kDisplayVendorID));
            productIDRef = CFDictionaryGetValue(info,
                                                CFSTR(kDisplayProductID));
            serialNumberRef = CFDictionaryGetValue(info,
                                                   CFSTR(kDisplaySerialNumber));
            
            success = CFNumberGetValue(vendorIDRef, kCFNumberCFIndexType,
                                       &vendorID);
            success &= CFNumberGetValue(productIDRef, kCFNumberCFIndexType,
                                        &productID);
            success &= CFNumberGetValue(serialNumberRef, kCFNumberCFIndexType,
                                        &serialNumber);
            
            if (!success)
            {
                CFRelease(info);
                continue;
            }
            
            // If the vendor and product id along with the serial don't match
            // then we are not looking at the correct monitor.
            // NOTE: The serial number is important in cases where two monitors
            //       are the exact same.
            if (CGDisplayVendorNumber(displayID) != vendorID  ||
                CGDisplayModelNumber(displayID) != productID  ||
                CGDisplaySerialNumber(displayID) != serialNumber)
            {
                CFRelease(info);
                continue;
            }
            
            // The VendorID, Product ID, and the Serial Number all Match Up!
            // Therefore we have found the appropriate display io_service
            servicePort = serv;
            CFRelease(info);
            break;
        }
        
        IOObjectRelease(iter);
        return servicePort;
    }
