/*
 * @APPLE_LICENSE_HEADER_START@
 * 
 * Copyright (c) 1999-2003 Apple Computer, Inc.  All Rights Reserved.
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */

/*
 * Changes to this API are expected.
 */

#ifndef _IOKIT_IOHIDLibUserClient_H_
#define _IOKIT_IOHIDLibUserClient_H_

#include <IOKit/hid/IOHIDKeys.h>

#define kMaxLocalCookieArrayLength  512

enum IOHIDLibUserClientConnectTypes {
	kIOHIDLibUserClientConnectManager = 0x00484944 /* HID */
};
 
// vtn3: there used to be an evil hack here.  that hack has gone away.
enum IOHIDLibUserClientMemoryTypes {
	kIOHIDLibUserClientElementValuesType = 0
};

// port types: I did consider adding queue ports to this
// as well, but i'm not comfty with sending object pointers
// as a type.
enum IOHIDLibUserClientPortTypes {
	kIOHIDLibUserClientAsyncPortType = 0,
	kIOHIDLibUserClientDeviceValidPortType
};

enum IOHIDLibUserClientCommandCodes {
	kIOHIDLibUserClientDeviceIsValid,
	kIOHIDLibUserClientOpen,
	kIOHIDLibUserClientClose,
	kIOHIDLibUserClientCreateQueue,
	kIOHIDLibUserClientDisposeQueue,
	kIOHIDLibUserClientAddElementToQueue,
	kIOHIDLibUserClientRemoveElementFromQueue,
	kIOHIDLibUserClientQueueHasElement,
	kIOHIDLibUserClientStartQueue,
	kIOHIDLibUserClientStopQueue,
	kIOHIDLibUserClientUpdateElementValues,
	kIOHIDLibUserClientPostElementValues,
	kIOHIDLibUserClientGetReport,
	kIOHIDLibUserClientSetReport,
	kIOHIDLibUserClientGetElementCount,
	kIOHIDLibUserClientGetElements,
	kIOHIDLibUserClientSetQueueAsyncPort,
	kIOHIDLibUserClientNumCommands
};

__BEGIN_DECLS

typedef struct _IOHIDElementValue
{
	IOHIDElementCookie	cookie;
	UInt32				totalSize;
	AbsoluteTime		timestamp;
	UInt32				generation;
	UInt32				value[1];
}IOHIDElementValue;

typedef struct _IOHIDReportReq
{
	UInt32		reportType;
	UInt32		reportID;
	void		*reportBuffer;
	UInt32		reportBufferSize;
}IOHIDReportReq;

struct IOHIDElementStruct;
typedef struct IOHIDElementStruct IOHIDElementStruct;
struct IOHIDElementStruct
{
	UInt32				cookieMin;
	UInt32				cookieMax;
	UInt32				parentCookie;
	UInt32				type;
	UInt32				collectionType;
	UInt32				flags;
	UInt32				usagePage;
	UInt32				usageMin;
	UInt32				usageMax;
	SInt32				min;
	SInt32				max;
	SInt32				scaledMin;
	SInt32				scaledMax;
	UInt32				size;
	UInt32				reportSize;
	UInt32				reportCount;
	UInt32				reportID;
	UInt32				unit;
	UInt32				unitExponent;
	UInt32				duplicateValueSize;
	UInt32				duplicateIndex;
	UInt32				bytes;
	UInt32				valueLocation;
	UInt32				valueSize;
};

enum {
	kHIDElementType			= 0,
	kHIDReportHandlerType
};

__END_DECLS

#if KERNEL

#include <mach/mach_types.h>
#include <IOKit/IOUserClient.h>
#include <IOKit/IOInterruptEventSource.h>

class IOHIDDevice;
class IOHIDEventQueue;
class IOSyncer;
struct IOHIDCompletion;

enum {
	kHIDQueueStateEnable,
	kHIDQueueStateDisable,
	kHIDQueueStateClear
};

class IOHIDLibUserClient : public IOUserClient 
{
	OSDeclareDefaultStructors(IOHIDLibUserClient)
	
	bool resourceNotification(void *refCon, IOService *service, IONotifier *notifier);
	void resourceNotificationGated();
	
	void setStateForQueues(UInt32 state, IOOptionBits options = 0);
	
	void setValid(bool state);
	
	IOReturn dispatchMessage(void* message);

public:
	bool attach(IOService * provider);
	
protected:
	static const IOExternalMethodDispatch
		sMethods[kIOHIDLibUserClientNumCommands];

	IOHIDDevice *fNub;
	IOWorkLoop *fWL;
	IOCommandGate *fGate;
	IOInterruptEventSource * fResourceES;
	
	OSArray *fQueueMap;

	UInt32 fPid;
	task_t fClient;
	mach_port_t fWakePort;
	mach_port_t fValidPort;
	
	void * fValidMessage;
	
	bool fNubIsTerminated;
	bool fNubIsKeyboard;
	
	IOOptionBits fCachedOptionBits;
		
	IONotifier * fResourceNotification;
	
	UInt64 fCachedConsoleUsersSeed;
	
	bool	fValid;
	uint64_t fGeneration;
	// Methods
	virtual bool initWithTask(task_t owningTask, void *security_id, UInt32 type);
	
	virtual IOReturn clientClose(void);

	virtual bool start(IOService *provider);
	virtual void stop(IOService *provider);

	virtual bool didTerminate(IOService *provider, IOOptionBits options, bool *defer);
		
	virtual void free();

	virtual void cleanupGated();
	
	virtual IOReturn message(UInt32 type, IOService * provider, void * argument = 0 );
	virtual IOReturn messageGated(UInt32 type, IOService * provider, void * argument = 0 );

	virtual IOReturn registerNotificationPort(mach_port_t port, UInt32 type, UInt32 refCon );
	virtual IOReturn registerNotificationPortGated(mach_port_t port, UInt32 type, UInt32 refCon );

	// return the shared memory for type (called indirectly)
	virtual IOReturn clientMemoryForType(
						UInt32				type,
						IOOptionBits *		options,
						IOMemoryDescriptor ** memory );
	IOReturn clientMemoryForTypeGated(
						UInt32				type,
						IOOptionBits *		options,
						IOMemoryDescriptor ** memory );
						
	IOReturn externalMethod(	uint32_t					selector, 
								IOExternalMethodArguments * arguments,
								IOExternalMethodDispatch *  dispatch, 
								OSObject *				target, 
								void *					reference);

	IOReturn externalMethodGated(void * args);


	// Open the IOHIDDevice
	static IOReturn _open(IOHIDLibUserClient * target, void * reference, IOExternalMethodArguments * arguments);
	IOReturn		open(IOOptionBits options);

	// Close the IOHIDDevice
	static IOReturn _close(IOHIDLibUserClient * target, void * reference, IOExternalMethodArguments * arguments);
	IOReturn		close();
				
	// Get Element Counts
	static IOReturn _getElementCount(IOHIDLibUserClient * target, void * reference, IOExternalMethodArguments * arguments);	
	IOReturn		getElementCount(uint64_t * outElementCount, uint64_t * outReportElementCount);

	// Get Elements
	static IOReturn _getElements(IOHIDLibUserClient * target, void * reference, IOExternalMethodArguments * arguments);	
	IOReturn		getElements(uint32_t elementType, void *elementBuffer, uint32_t *elementBufferSize);
	IOReturn		getElements(uint32_t elementType, IOMemoryDescriptor * mem,  uint32_t *elementBufferSize);

	// Device Valid
	static IOReturn _deviceIsValid(IOHIDLibUserClient * target, void * reference, IOExternalMethodArguments * arguments);	
	IOReturn		deviceIsValid(bool *status, uint64_t *generation);
	
	// Set queue port
	static IOReturn _setQueueAsyncPort(IOHIDLibUserClient * target, void * reference, IOExternalMethodArguments * arguments);
	IOReturn		setQueueAsyncPort(IOHIDEventQueue * queue, mach_port_t port);

	// Create a queue
	static IOReturn _createQueue(IOHIDLibUserClient * target, void * reference, IOExternalMethodArguments * arguments);
	IOReturn		createQueue(uint32_t flags, uint32_t depth, uint64_t * outQueue);

	// Dispose a queue
	static IOReturn _disposeQueue(IOHIDLibUserClient * target, void * reference, IOExternalMethodArguments * arguments);
	IOReturn		disposeQueue(IOHIDEventQueue * queue);

	// Add an element to a queue
	static IOReturn _addElementToQueue(IOHIDLibUserClient * target, void * reference, IOExternalMethodArguments * arguments);
	IOReturn		addElementToQueue(IOHIDEventQueue * queue, IOHIDElementCookie elementCookie, uint32_t flags, uint64_t *pSizeChange);
   
	// remove an element from a queue
	static IOReturn _removeElementFromQueue (IOHIDLibUserClient * target, void * reference, IOExternalMethodArguments * arguments);
	IOReturn		removeElementFromQueue (IOHIDEventQueue * queue, IOHIDElementCookie elementCookie, uint64_t *pSizeChange);
	
	// Check to see if a queue has an element
	static IOReturn _queueHasElement (IOHIDLibUserClient * target, void * reference, IOExternalMethodArguments * arguments);
	IOReturn		queueHasElement (IOHIDEventQueue * queue, IOHIDElementCookie elementCookie, uint64_t * pHasElement);
	
	// start a queue
	static IOReturn _startQueue (IOHIDLibUserClient * target, void * reference, IOExternalMethodArguments * arguments);
	IOReturn		startQueue (IOHIDEventQueue * queue);
	
	// stop a queue
	static IOReturn _stopQueue (IOHIDLibUserClient * target, void * reference, IOExternalMethodArguments * arguments);
	IOReturn		stopQueue (IOHIDEventQueue * queue);
							
	// Update Feature element value
	static IOReturn	_updateElementValues (IOHIDLibUserClient * target, void * reference, IOExternalMethodArguments * arguments);
	IOReturn		updateElementValues (const uint64_t * lCookies, uint32_t cookieCount);
												
	// Post element value
	static IOReturn _postElementValues (IOHIDLibUserClient * target, void * reference, IOExternalMethodArguments * arguments);
	IOReturn		postElementValues (const uint64_t * lCookies, uint32_t cookieCount);
												
	// Get report
	static IOReturn _getReport(IOHIDLibUserClient * target, void * reference, IOExternalMethodArguments * arguments);
	IOReturn		getReport(void *reportBuffer, uint32_t *pOutsize, IOHIDReportType reportType, uint32_t reportID, uint32_t timeout = 0, IOHIDCompletion * completion = 0);
	IOReturn		getReport(IOMemoryDescriptor * mem, uint32_t * pOutsize, IOHIDReportType reportType, uint32_t reportID, uint32_t timeout = 0, IOHIDCompletion * completion = 0); 

	// Set report
	static IOReturn _setReport(IOHIDLibUserClient * target, void * reference, IOExternalMethodArguments * arguments);
	IOReturn		setReport(const void *reportBuffer, uint32_t reportBufferSize, IOHIDReportType reportType, uint32_t reportID, uint32_t timeout = 0, IOHIDCompletion * completion = 0);
	IOReturn		setReport(IOMemoryDescriptor * mem, IOHIDReportType reportType, uint32_t reportID, uint32_t timeout = 0, IOHIDCompletion * completion = 0);

	void ReqComplete(void *param, IOReturn status, UInt32 remaining);
	IOReturn ReqCompleteGated(void *param, IOReturn status, UInt32 remaining);

	u_int createTokenForQueue(IOHIDEventQueue *queue);
	void removeQueueFromMap(IOHIDEventQueue *queue);
	IOHIDEventQueue* getQueueForToken(u_int token);
	
	// Iterator over valid tokens.  Start at 0 (not a valid token) 
	// and keep calling it with the return value till you get 0 
	// (still not a valid token).  vtn3
	u_int getNextTokenForToken(u_int token);
};

#endif /* KERNEL */

#endif /* ! _IOKIT_IOHIDLibUserClient_H_ */

