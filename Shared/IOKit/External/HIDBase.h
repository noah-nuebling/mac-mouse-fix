/// Src: https://opensource.apple.com/source/IOHIDFamily/IOHIDFamily-1633.120.12/HID/HIDBase.h.auto.html

//
//  HIDBase.h
//  HID
//
//  Created by dekom on 10/31/17.
//

#ifndef HIDBase_h
#define HIDBase_h

#import <Foundation/Foundation.h>
#import "hidobjcbase.h" /** #import <IOKit/hidobjc/hidobjcbase.h> */

NS_ASSUME_NONNULL_BEGIN

#if defined(__cplusplus)
#define HID_EXPORT extern "C"
#else
#define HID_EXPORT extern
#endif

@class HIDDevice;
@class HIDElement;
@class HIDEvent;

// IOKit forward declares
typedef uint32_t IOHIDEventField;
typedef kern_return_t IOReturn;
typedef mach_port_t io_object_t;
typedef io_object_t io_service_t;
//typedef uint32_t IOHIDEventType;

/*!
 * @typedef HIDReportType
 *
 * @abstract
 * Enumerator of report types.
 */
typedef NS_ENUM(NSInteger, HIDReportType) {
    HIDReportTypeInput,
    HIDReportTypeOutput,
    HIDReportTypeFeature
};

/*!
 * @typedef HIDReportHandler
 *
 * @abstract
 * The type of block used for HID input reports.
 */
typedef void (^HIDReportHandler)(HIDDevice *sender,
                                 uint64_t timestamp,
                                 HIDReportType type,
                                 NSInteger reportID,
                                 NSData *report);

/*!
 * @typedef HIDBlock
 *
 * @abstract
 * A generic block used in conjunction with HID objects.
 */
typedef void (^HIDBlock)(void);

/*!
 * @typedef HIDServiceEventDispatchHandler
 *
 * @abstract
 * A callback used for dispatching HIDEvents from a plugin/filter.
 */
typedef void (*HIDServiceEventDispatchHandler)(void * _Nullable target,
                                               HIDEvent *event);

NS_ASSUME_NONNULL_END

#endif /* HIDBase_h */
