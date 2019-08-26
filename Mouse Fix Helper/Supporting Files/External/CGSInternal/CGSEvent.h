//
//  CGSEvent.h
//  CGSInternal
//
//  Created by Robert Widmann on 9/14/13.
//  Copyright (c) 2015-2016 CodaFi. All rights reserved.
//  Released under the MIT license.
//

#ifndef CGS_EVENT_INTERNAL_H
#define CGS_EVENT_INTERNAL_H

#include "CGSWindow.h"

typedef unsigned long CGSByteCount;
typedef unsigned short CGSEventRecordVersion;
typedef unsigned long long CGSEventRecordTime;  /* nanosecond timer */
typedef unsigned long CGSEventFlag;
typedef unsigned long  CGSError;

typedef enum : unsigned int {
	kCGSDisplayWillReconfigure = 100,
	kCGSDisplayDidReconfigure = 101,
	kCGSDisplayWillSleep = 102,
	kCGSDisplayDidWake = 103,
	kCGSDisplayIsCaptured = 106,
	kCGSDisplayIsReleased = 107,
	kCGSDisplayAllDisplaysReleased = 108,
	kCGSDisplayHardwareChanged = 111,
	kCGSDisplayDidReconfigure2 = 115,
	kCGSDisplayFullScreenAppRunning = 116,
	kCGSDisplayFullScreenAppDone = 117,
	kCGSDisplayReconfigureHappened = 118,
	kCGSDisplayColorProfileChanged = 119,
	kCGSDisplayZoomStateChanged = 120,
	kCGSDisplayAcceleratorChanged = 121,
	kCGSDebugOptionsChangedNotification = 200,
	kCGSDebugPrintResourcesNotification = 203,
	kCGSDebugPrintResourcesMemoryNotification = 205,
	kCGSDebugPrintResourcesContextNotification = 206,
	kCGSDebugPrintResourcesImageNotification = 208,
	kCGSServerConnDirtyScreenNotification = 300,
	kCGSServerLoginNotification = 301,
	kCGSServerShutdownNotification = 302,
	kCGSServerUserPreferencesLoadedNotification = 303,
	kCGSServerUpdateDisplayNotification = 304,
	kCGSServerCAContextDidCommitNotification = 305,
	kCGSServerUpdateDisplayCompletedNotification = 306,

	kCPXForegroundProcessSwitched = 400,
	kCPXSpecialKeyPressed = 401,
	kCPXForegroundProcessSwitchRequestedButRedundant = 402,

	kCGSSpecialKeyEventNotification = 700,

	kCGSEventNotificationNullEvent = 710,
	kCGSEventNotificationLeftMouseDown = 711,
	kCGSEventNotificationLeftMouseUp = 712,
	kCGSEventNotificationRightMouseDown = 713,
	kCGSEventNotificationRightMouseUp = 714,
	kCGSEventNotificationMouseMoved = 715,
	kCGSEventNotificationLeftMouseDragged = 716,
	kCGSEventNotificationRightMouseDragged = 717,
	kCGSEventNotificationMouseEntered = 718,
	kCGSEventNotificationMouseExited = 719,

	kCGSEventNotificationKeyDown = 720,
	kCGSEventNotificationKeyUp = 721,
	kCGSEventNotificationFlagsChanged = 722,
	kCGSEventNotificationKitDefined = 723,
	kCGSEventNotificationSystemDefined = 724,
	kCGSEventNotificationApplicationDefined = 725,
	kCGSEventNotificationTimer = 726,
	kCGSEventNotificationCursorUpdate = 727,
	kCGSEventNotificationSuspend = 729,
	kCGSEventNotificationResume = 730,
	kCGSEventNotificationNotification = 731,
	kCGSEventNotificationScrollWheel = 732,
	kCGSEventNotificationTabletPointer = 733,
	kCGSEventNotificationTabletProximity = 734,
	kCGSEventNotificationOtherMouseDown = 735,
	kCGSEventNotificationOtherMouseUp = 736,
	kCGSEventNotificationOtherMouseDragged = 737,
	kCGSEventNotificationZoom = 738,
	kCGSEventNotificationAppIsUnresponsive = 750,
	kCGSEventNotificationAppIsNoLongerUnresponsive = 751,

	kCGSEventSecureTextInputIsActive = 752,
	kCGSEventSecureTextInputIsOff = 753,

	kCGSEventNotificationSymbolicHotKeyChanged = 760,
	kCGSEventNotificationSymbolicHotKeyDisabled = 761,
	kCGSEventNotificationSymbolicHotKeyEnabled = 762,
	kCGSEventNotificationHotKeysGloballyDisabled = 763,
	kCGSEventNotificationHotKeysGloballyEnabled = 764,
	kCGSEventNotificationHotKeysExceptUniversalAccessGloballyDisabled = 765,
	kCGSEventNotificationHotKeysExceptUniversalAccessGloballyEnabled = 766,

	kCGSWindowIsObscured = 800,
	kCGSWindowIsUnobscured = 801,
	kCGSWindowIsOrderedIn = 802,
	kCGSWindowIsOrderedOut = 803,
	kCGSWindowIsTerminated = 804,
	kCGSWindowIsChangingScreens = 805,
	kCGSWindowDidMove = 806,
	kCGSWindowDidResize = 807,
	kCGSWindowDidChangeOrder = 808,
	kCGSWindowGeometryDidChange = 809,
	kCGSWindowMonitorDataPending = 810,
	kCGSWindowDidCreate = 811,
	kCGSWindowRightsGrantOffered = 812,
	kCGSWindowRightsGrantCompleted = 813,
	kCGSWindowRecordForTermination = 814,
	kCGSWindowIsVisible = 815,
	kCGSWindowIsInvisible = 816,

	kCGSLikelyUnbalancedDisableUpdateNotification = 902,

	kCGSConnectionWindowsBecameVisible = 904,
	kCGSConnectionWindowsBecameOccluded = 905,
	kCGSConnectionWindowModificationsStarted = 906,
	kCGSConnectionWindowModificationsStopped = 907,

	kCGSWindowBecameVisible = 912,
	kCGSWindowBecameOccluded = 913,

	kCGSServerWindowDidCreate = 1000,
	kCGSServerWindowWillTerminate = 1001,
	kCGSServerWindowOrderDidChange = 1002,
	kCGSServerWindowDidTerminate = 1003,
	
	kCGSWindowWasMovedByDockEvent = 1205,
	kCGSWindowWasResizedByDockEvent = 1207,
	kCGSWindowDidBecomeManagedByDockEvent = 1208,
	
	kCGSServerMenuBarCreated = 1300,
	kCGSServerHidBackstopMenuBar = 1301,
	kCGSServerShowBackstopMenuBar = 1302,
	kCGSServerMenuBarDrawingStyleChanged = 1303,
	kCGSServerPersistentAppsRegistered = 1304,
	kCGSServerPersistentCheckinComplete = 1305,

	kCGSPackagesWorkspacesDisabled = 1306,
	kCGSPackagesWorkspacesEnabled = 1307,
	kCGSPackagesStatusBarSpaceChanged = 1308,

	kCGSWorkspaceWillChange = 1400,
	kCGSWorkspaceDidChange = 1401,
	kCGSWorkspaceWindowIsViewable = 1402,
	kCGSWorkspaceWindowIsNotViewable = 1403,
	kCGSWorkspaceWindowDidMove = 1404,
	kCGSWorkspacePrefsDidChange = 1405,
	kCGSWorkspacesWindowDragDidStart = 1411,
	kCGSWorkspacesWindowDragDidEnd = 1412,
	kCGSWorkspacesWindowDragWillEnd = 1413,
	kCGSWorkspacesShowSpaceForProcess = 1414,
	kCGSWorkspacesWindowDidOrderInOnNonCurrentManagedSpacesOnly = 1415,
	kCGSWorkspacesWindowDidOrderOutOnNonCurrentManagedSpaces = 1416,

	kCGSessionConsoleConnect = 1500,
	kCGSessionConsoleDisconnect = 1501,
	kCGSessionRemoteConnect = 1502,
	kCGSessionRemoteDisconnect = 1503,
	kCGSessionLoggedOn = 1504,
	kCGSessionLoggedOff = 1505,
	kCGSessionConsoleWillDisconnect = 1506,
	kCGXWillCreateSession = 1550,
	kCGXDidCreateSession = 1551,
	kCGXWillDestroySession = 1552,
	kCGXDidDestroySession = 1553,
	kCGXWorkspaceConnected = 1554,
	kCGXSessionReleased = 1555,

	kCGSTransitionDidFinish = 1700,

	kCGXServerDisplayHardwareWillReset = 1800,
	kCGXServerDesktopShapeChanged = 1801,
	kCGXServerDisplayConfigurationChanged = 1802,
	kCGXServerDisplayAcceleratorOffline = 1803,
	kCGXServerDisplayAcceleratorDeactivate = 1804,
} CGSEventType;


#pragma mark - System-Level Event Notification Registration


typedef void (*CGSNotifyProcPtr)(CGSEventType type, void *data, unsigned int dataLength, void *userData);

/// Registers a function to receive notifications for system-wide events.
CG_EXTERN CGError CGSRegisterNotifyProc(CGSNotifyProcPtr proc, CGSEventType type, void *userData);

/// Unregisters a function that was registered to receive notifications for system-wide events.
CG_EXTERN CGError CGSRemoveNotifyProc(CGSNotifyProcPtr proc, CGSEventType type, void *userData);


#pragma mark - Application-Level Event Notification Registration


typedef void (*CGConnectionNotifyProc)(CGSEventType type, CGSNotificationData notificationData, size_t dataLength, CGSNotificationArg userParameter, CGSConnectionID);

/// Registers a function to receive notifications for connection-level events.
CG_EXTERN CGError CGSRegisterConnectionNotifyProc(CGSConnectionID cid, CGConnectionNotifyProc function, CGSEventType event, void *userData);

/// Unregisters a function that was registered to receive notifications for connection-level events.
CG_EXTERN CGError CGSRemoveConnectionNotifyProc(CGSConnectionID cid, CGConnectionNotifyProc function, CGSEventType event, void *userData);


typedef struct _CGSEventRecord {
	CGSEventRecordVersion major; /*0x0*/
	CGSEventRecordVersion minor; /*0x2*/
	CGSByteCount length;         /*0x4*/ /* Length of complete event record */
	CGSEventType type;           /*0x8*/ /* An event type from above */
	CGPoint location;            /*0x10*/ /* Base coordinates (global), from upper-left */
	CGPoint windowLocation;      /*0x20*/ /* Coordinates relative to window */
	CGSEventRecordTime time;     /*0x30*/ /* nanoseconds since startup */
	CGSEventFlag flags;         /* key state flags */
	CGWindowID window;         /* window number of assigned window */
	CGSConnectionID connection; /* connection the event came from */
	struct __CGEventSourceData {
		int source;
		unsigned int sourceUID;
		unsigned int sourceGID;
		unsigned int flags;
		unsigned long long userData;
		unsigned int sourceState;
		unsigned short localEventSuppressionInterval;
		unsigned char suppressionIntervalFlags;
		unsigned char remoteMouseDragFlags;
		unsigned long long serviceID;
	} eventSource;
	struct _CGEventProcess {
		int pid;
		unsigned int psnHi;
		unsigned int psnLo;
		unsigned int targetID;
		unsigned int flags;
	} eventProcess;
	NXEventData eventData;
	SInt32 _padding[4];
	void *ioEventData;
	unsigned short _field16;
	unsigned short _field17;
	struct _CGSEventAppendix {
		unsigned short windowHeight;
		unsigned short mainDisplayHeight;
		unsigned short *unicodePayload;
		unsigned int eventOwner;
		unsigned char passedThrough;
	} *appendix;
	unsigned int _field18;
	bool passedThrough;
	CFDataRef data;
} CGSEventRecord;

/// Gets the event record for a given `CGEventRef`.
///
/// For Carbon events, use `GetEventPlatformEventRecord`.
CG_EXTERN CGError CGEventGetEventRecord(CGEventRef event, CGSEventRecord *outRecord, size_t recSize);

/// Gets the main event port for the connection ID.
CG_EXTERN OSErr CGSGetEventPort(CGSConnectionID identifier, mach_port_t *port);

/// Getter and setter for the background event mask.
CG_EXTERN void CGSGetBackgroundEventMask(CGSConnectionID cid, int *outMask);
CG_EXTERN CGError CGSSetBackgroundEventMask(CGSConnectionID cid, int mask);


/// Returns	`True` if the application has been deemed unresponsive for a certain amount of time.
CG_EXTERN bool CGSEventIsAppUnresponsive(CGSConnectionID cid, const ProcessSerialNumber *psn);

/// Sets the amount of time it takes for an application to be considered unresponsive.
CG_EXTERN CGError CGSEventSetAppIsUnresponsiveNotificationTimeout(CGSConnectionID cid, double theTime);

#pragma mark input

// Gets and sets the status of secure input. When secure input is enabled, keyloggers, etc are harder to do.
CG_EXTERN bool CGSIsSecureEventInputSet(void);
CG_EXTERN CGError CGSSetSecureEventInput(CGSConnectionID cid, bool useSecureInput);

#endif /* CGS_EVENT_INTERNAL_H */
