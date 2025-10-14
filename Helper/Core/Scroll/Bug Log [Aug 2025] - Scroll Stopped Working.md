
 [Aug 28 2025]
 I just experienced a 'Scroll Stops Working' bug myself for the first time!
 What I remember:
    - Running Tahoe Beta 8, MMF 3.0.7 (24077) (I think), mouse attached via two dongles with no power attached. Mac was almost out of battery.
    - Scrolling stopped working entirely
    - Setting the smoothness to off did *not* fix it (Contrary to many of the reports we've seen)
    - Rolling the wheel got MMF Helper to around 0.6% in Activity monitor (lower than normal). When not scrolling, the CPU usage was at 0%.
    - Killing the helper fixed things
    - Sampled with instruments (See below) while scrolling and it showed:
        - That time was spent in eventTapCallback() but *all* of its time was spent in `SLEventCreateCopy`. (Probably CGEventCreateCopy())
            - ... Actually, instruments says that the *caller* of eventTapCallback() – processEventTapData() from SkyLight – was calling our CGEvent_IsWacomEvent() and CGEventGetTimestampInSeconds ––– This doesn't make sense?
            - ... And actually, instruments shows that there was another code branch that was spending most of its time in `__eventTapCallback_block_invoke > sendScroll() > SLEventPost`! So our code was sending events!
        - I'm not sure whether I sampled with `Smoothness: Off`
    - Explanation ideas:
        - Maybe there was that deadlock we described in `Old MFDisplayLinkWorkType stuff.md`, and then when we turned off smooth scrolling, MMF tried to send events from another thread, but the deadlock clogged up or interrupted macOS's event processing somehow? (Not sure that's possible)
        - Maybe it was a macOS bug? Evidence:
            - Earlier today I had a bug where the computer would freeze when I typed the first letter of my password on the lockscreen, unless I plugged out the mouse I was using also when this bug occurred (VXE R1 SE+)
            - See the IOServiceOpen error logs below.

## Also See

- `Old MFDisplayLinkWorkType stuff.md > Deadlock: [Aug 2025]`
- 'Scroll Stops Working Intermittently' Issue Category on GitHub
 
## Mistakes

I should probably made an Activity Monitor sample before killing the Helper. (See `Old MFDisplayLinkWorkType stuff.md > Deadlock: [Aug 2025]`)
    I thought the Instruments Trace was enough – but now I'm not sure.

## Trace

I saved the instruments trace as 
`Bug Trace [Aug 2025] - Scroll Stopped Working.trace`

I won't add it to the repo for now cause it's 1.4 MB even compressed.

## Sysdiagnose

I made this sysdiagnose while writing this Bug Log:
`sysdiagnose_2025.08.28_22-31-37+0200_636_macOS_Mac_25A5349a.tar.gz`

It's 400 MB compressed, so I won't add it to the repo.

## Logs 

While it was not working, I attached a debugger to MMF Helper. Didn't see any messages while scrolling (I think because not a verbose-logging-build), but plugging in and out the mouse and I always saw logs containing errors: 
         (not sure this is normal)
         (Update: After a restart, when things worked again, I looked at the logs again, and I still saw the errors after and including "probe failed for plugin for" still occur. But the errors after and including `IOServiceOpen failed:` aren't logged anymore – so I think this points to a macOS bug.)
Logs:
 ```
     IOServiceOpen failed: 0x e00002e2
     Error opening device. Code: e00002e2
     IOServiceOpen failed: 0x e00002e2
     New device added to attached devices:
     Device Info:
         Product: VXE R1SE+
         Manufacturer: Compx
         nOfButtons: 0
         UsagePairs: (
             {
             DeviceUsage = 2;
             DeviceUsagePage = 1;
         },
             {
             DeviceUsage = 1;
             DeviceUsagePage = 1;
         },
             {
             DeviceUsage = 56;
             DeviceUsagePage = 1;
         },
             {
             DeviceUsage = 568;
             DeviceUsagePage = 1;
         }
     )
         ProductID: 62863
         VendorID: 13652
     probe failed for plugin for  <private>
     IOCreatePlugInInterfaceForService:0x e00002be  for serviceID: 100004793
     io_service_t has no IOCFPlugInTypes for  <private>
     onePlugin invalid for pluginType  <private>
     bundle invalid for pluginType  <private>
     plist invalid for pluginType  <private>
     no factories for plugin for  <private> , kr = 0x 0 , factories =  0x0 , factoryCount =  0
     IOCreatePlugInInterfaceForService:0x e00002c7  for serviceID: 10000478f
     Attached device was removed:
     Device Info:
         Product: VXE R1SE+
         Manufacturer: Compx
         nOfButtons: 0
         UsagePairs: (
             {
             DeviceUsage = 2;
             DeviceUsagePage = 1;
         },
             {
             DeviceUsage = 1;
             DeviceUsagePage = 1;
         },
             {
             DeviceUsage = 56;
             DeviceUsagePage = 1;
         },
             {
             DeviceUsage = 568;
             DeviceUsagePage = 1;
         }
     )
         ProductID: 62863
         VendorID: 13652
     IOServiceOpen failed: 0x e00002e2
     Error opening device. Code: e00002e2
     IOServiceOpen failed: 0x e00002e2
     ...
 ```
