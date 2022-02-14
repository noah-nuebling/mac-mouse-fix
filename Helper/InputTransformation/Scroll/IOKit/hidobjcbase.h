//
//  hidobjcbase.h
//  IOKitUser
//
//  Created by dekom on 9/11/18.
//

#ifndef hidobjcbase_h
#define hidobjcbase_h

#import <CoreFoundation/CoreFoundation.h>

CF_ASSUME_NONNULL_BEGIN

/*
 * Here is where we forward declare everything, so that we don't have to be
 * dependent on the IOKit framework. This will make us a modular framework,
 * which will allow the HID framework to link against us without swift compiler
 * errors.
 */

/*
 * IOKit forward declares
 */
#ifndef __IOKIT_IOTYPES_H
typedef mach_port_t io_object_t;
typedef io_object_t io_service_t;
typedef UInt32 IOOptionBits;
#endif

#ifndef _IOKIT_IOCFPLUGIN_H_
typedef struct IOCFPlugInInterfaceStruct IOCFPlugInInterface;
#endif

#ifndef __IOKIT_IORETURN_H
typedef kern_return_t IOReturn;
#endif

#ifndef _MACH_MACH_TYPES_H_
typedef mach_port_t task_t;
#endif

#ifndef _IO_MIG_MACH_PORT_H_
typedef struct __IOMIGMachPort *IOMIGMachPortRef;
#endif


/*
 * misc forward declares
 */
#ifndef _IOKIT_HID_IOHIDLIBPRIVATE_H
typedef CFDataRef IOHIDSimpleQueueRef;
typedef struct _IOHIDCalibrationStruct IOHIDCalibrationInfo;
#endif

#ifndef _IOKIT_IOKITLIB_H
typedef struct IONotificationPort *IONotificationPortRef;
#endif

#ifndef __OS_LOG_H__
#if OS_OBJECT_USE_OBJC
OS_OBJECT_DECL(os_log);
#elif !OS_OBJECT_SWIFT3
typedef struct os_log_s *os_log_t;
#endif /* OS_OBJECT_USE_OBJC */
#endif

#ifndef __DISPATCH_MACH_PRIVATE__
DISPATCH_DECL(dispatch_mach);
#endif

/*
 * IOHIDEvent forward declares
 */
#ifndef _IOKIT_IOHIDEVENTTYPES_H
//typedef uint32_t IOHIDEventType;
#endif

#ifndef _IOKIT_IOHIDEVENTDATA_H
typedef struct IOHIDEventData IOHIDEventData;
#endif

#ifndef _IOKIT_HID_IOHIDEVENT_H
typedef struct __IOHIDEvent *IOHIDEventRef;

typedef void (*IOHIDEventCallback)(void * _Nullable target,
                                   void * _Nullable refcon,
                                   void * _Nullable sender,
                                   IOHIDEventRef event);
#endif


/*
 * IOHIDService forward declares
 */
#ifndef _IOKIT_HID_HIDTYPES_H
typedef struct __IOHIDService *IOHIDServiceRef;
typedef struct __IOHIDSession *IOHIDSessionRef;
typedef const struct __IOHIDNotification *IOHIDNotificationRef;
#endif

#ifndef _IOKIT_HID_IOHIDSERVICEPLUGIN_H_
typedef struct IOHIDServiceInterface IOHIDServiceInterface;
typedef struct IOHIDServiceInterface2 IOHIDServiceInterface2;
typedef struct IOHIDServiceFastPathInterface IOHIDServiceFastPathInterface;

typedef void (*IOHIDServiceEventCallback)(void * _Nullable target,
                                          void * _Nullable refcon,
                                          void * _Nullable sender,
                                          IOHIDEventRef event,
                                          IOOptionBits options);
#endif

#ifndef _IOKIT_HID_HIDSERVICE_PRIVATE_H
typedef struct IOHIDServiceVirtualCallbacksV2 IOHIDServiceVirtualCallbacksV2;
typedef struct __IOHIDServiceQueueContext __IOHIDServiceQueueContext;
#endif

#ifndef _IOKIT_HID_SESSION_PRIVATE_H
typedef struct __IOHIDSessionQueueContext __IOHIDSessionQueueContext;
#endif

/*
 * IOHIDSession forward declares
 */
#ifndef _IOKIT_HID_IOHIDEVENTSYSTEM_H
typedef struct __IOHIDEventSystem *IOHIDEventSystemRef;
#endif

/*
 * IOHIDConnection forward declares
 */
#ifndef _IOKIT_HID_CONNECTION_FILTER_H
typedef struct  __IOHIDConnectionFilter *IOHIDConnectionFilterRef;
#endif

#ifndef _IOKIT_HID_IOHIDEVENTQUEUE_H
typedef struct __IOHIDEventQueue *IOHIDEventQueueRef;
#endif

#ifndef _IOKIT_HID_IOHIDEVENTSYSTEM_CONNECTION_H
typedef struct __IOHIDEventSystemConnection *IOHIDEventSystemConnectionRef;
#endif

#ifndef _IOKIT_HID_IOHIDEVENTSYSTEM_CONNECTION_PRIVATE_H
typedef void (*IOHIDEventSystemConnectionTerminationCallback)(IOHIDEventSystemConnectionRef client, void * _Nullable refcon);
typedef Boolean (*IOHIDEventSystemConnectionDemuxCallback)(IOHIDEventSystemConnectionRef client, mach_msg_header_t * request, mach_msg_header_t * reply, void * _Nullable refcon);

typedef union IOHIDEventSystemConnectionEntitlements IOHIDEventSystemConnectionEntitlements;
#endif

/*
 * IOHIDElement forward declares
 */

#ifndef _IOKIT_HID_IOHIDDEVICEPLUGIN_H
typedef struct IOHIDDeviceDeviceInterface IOHIDDeviceDeviceInterface;
typedef struct IOHIDDeviceTimeStampedDeviceInterface IOHIDDeviceTimeStampedDeviceInterface;
#endif

#ifndef _IOKIT_HID_IOHIDBASE_H_
typedef struct __IOHIDDevice *IOHIDDeviceRef;
typedef struct __IOHIDElement *IOHIDElementRef;
typedef struct __IOHIDValue *IOHIDValueRef;
#endif

#ifndef _IOKIT_IOHIDLibUserClient_H_
typedef struct IOHIDElementStruct IOHIDElementStruct;
#endif


/*
 * IOHIDServiceClient forward declares
 */
#ifndef IOHIDEventSystemClient_h
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;
#endif

#ifndef IOHIDServiceClient_h
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;
#endif

#ifndef _IOKIT_HID_IOHIDSERVICE_CLIENT_H
typedef void (*IOHIDServiceClientCallback)(void * _Nullable target,
                                           void * _Nullable refcon,
                                           IOHIDServiceClientRef service);

typedef void (^IOHIDServiceClientBlock)(void * _Nullable target,
                                        void * _Nullable refcon,
                                        IOHIDServiceClientRef service);

typedef struct __IOHIDVirtualServiceClientCallbacksV2 IOHIDVirtualServiceClientCallbacksV2;

typedef struct _IOHIDServiceClientUsagePair IOHIDServiceClientUsagePair;
#endif

#ifndef _IOKIT_HID_IOHIDQUEUE_USER_H
typedef struct __IOHIDQueue *IOHIDQueueRef;
#endif

CF_ASSUME_NONNULL_END

#endif /* hidobjcbase_h */
