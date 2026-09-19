/// Src: https://opensource.apple.com/source/IOHIDFamily/IOHIDFamily-1633.120.12/HID/HIDEvent.h.auto.html

//
//  HIDEvent.h
//  IOHIDFamily
//
//  Created by dekom on 12/20/17.
//

#ifndef HIDEvent_h
#define HIDEvent_h

//#import <Foundation/Foundation.h>
#import "HIDBase.h" /** <HID/HIDBase.h> */
#import "HIDEventBase.h" /** </hidobjc/HIDEventBase.h>*/
#import "IOHIDEventTypes.h"

NS_ASSUME_NONNULL_BEGIN

/*!
 * @enum HIDEventSerializationType
 *
 * @abstract
 * Enumerator of serialization types.
 *
 * @field HIDEventSerializationTypeFast
 * Fast serialization creates a NSData representation of the HIDEvent. It can
 * be useful for process to process event migration, but is not considered a
 * stable form of serialization, as an event can change over time.
 */
typedef NS_ENUM(NSInteger, HIDEventSerializationType) {
    HIDEventSerializationTypeFast
};

@interface HIDEvent (HIDFramework)  <NSCopying>

- (instancetype)init NS_UNAVAILABLE;

/*!
 * @method initWithType
 *
 * @abstract
 * Creates a HIDEvent object of the specified type.
 *
 * @param type
 * The event type to initialize. Event types can be found in
 * <IOKit/hid/IOHIDEventTypes.h>.
 *
 * @param timestamp
 * The timestamp of the event.
 *
 * @result
 * Returns an instance of a HIDEvent object on success.
 */
- (nullable instancetype)initWithType:(IOHIDEventType)type
                            timestamp:(uint64_t)timestamp
                             senderID:(uint64_t)senderID;

/*!
 * @method initWithData
 *
 * @abstract
 * Creates a HIDEvent based off serialized event data.
 *
 * @param data
 * Serialized event data, generally obtained through the serialize method.
 *
 * @result
 * Returns an instance of a HIDEvent object on success.
 */
- (nullable instancetype)initWithData:(NSData *)data;

/*!
 * @method initWithBytes
 *
 * @abstract
 * Creates a HIDEvent based off serialized event data.
 *
 * @param bytes
 * Serialized event bytes, generally obtained through the serialize method.
 *
 * @param length
 * The length of the bytes being passed in.
 *
 * @result
 * Returns an instance of a HIDEvent object on success.
 */
- (nullable instancetype)initWithBytes:(const void *)bytes
                                length:(NSInteger)length;

/*!
 * @method isEqualToHIDEvent
 *
 * @abstract
 * Compares two HIDEvent objects.
 *
 * @param event
 * The HIDEvent to compare against.
 *
 * @result
 * Returns true if the hid events are equal.
 */
- (BOOL)isEqualToHIDEvent:(HIDEvent *)event;

/*!
 * @method serialize
 *
 * @abstract
 * Creates a serialized representation of the HIDEvent
 *
 * @param type
 * The desired type of serialization. See the HIDEventSerializationType enum
 * for serialization types and their return types.
 *
 * @param outError
 * An error returned on failure.
 *
 * @result
 * Returns a serialized representation of the event on success.
 */
- (nullable NSData *)serialize:(HIDEventSerializationType)type
                         error:(out NSError * _Nullable * _Nullable)outError;

/*!
 * @method integerValueForField
 *
 * @abstract
 * Gets the integer value of the specified event field.
 *
 * @param field
 * The event field to query. Event fields can be found in
 * <IOKit/hid/IOHIDEventFieldDefs.h>.
 *
 * @result
 * Returns an integer value representation of the specified field.
 */
- (NSInteger)integerValueForField:(IOHIDEventField)field;

/*!
 * @method setIntegerValue
 *
 * @abstract
 * Sets the integer value of the specified event field.
 *
 * @param value
 * The value to set.
 *
 * @param field
 * The event field to set. Event fields can be found in
 * <IOKit/hid/IOHIDEventFieldDefs.h>.
 *
 */
- (void)setIntegerValue:(NSInteger)value forField:(IOHIDEventField)field;

/*!
 * @method doubleValueForField
 *
 * @abstract
 * Gets the double value of the specified event field.
 *
 * @param field
 * The event field to query. Event fields can be found in
 * <IOKit/hid/IOHIDEventFieldDefs.h>.
 *
 * @result
 * Returns a double value representation of the specified field.
 */
- (double)doubleValueForField:(IOHIDEventField)field;

/*!
 * @method setDoubleValue
 *
 * @abstract
 * Sets the double value of the specified event field.
 *
 * @param value
 * The value to set.
 *
 * @param field
 * The event field to set. Event fields can be found in
 * <IOKit/hid/IOHIDEventFieldDefs.h>.
 *
 */
- (void)setDoubleValue:(double)value forField:(IOHIDEventField)field;

/*!
 * @method dataValueForField
 *
 * @abstract
 * Gets the data value of the specified event field.
 *
 * @param field
 * The event field to query. Event fields can be found in
 * <IOKit/hid/IOHIDEventFieldDefs.h>.
 *
 * @result
 * Returns a pointer to the data value representation of the specified field.
 */
- (void *)dataValueForField:(IOHIDEventField)field;

/*!
 * @method appendEvent
 *
 * @abstract
 * Appends a child HID event to the HIDEvent object.
 *
 * @param event
 * The HID event to append.
 */
- (void)appendEvent:(HIDEvent *)event;

/*!
 * @method removeEvent
 *
 * @abstract
 * Removes a child HID event from the HIDEvent object. Comparison is done by
 * making sure the event type, options, and event data matches the passed in
 * HIDEvent.
 *
 * @param event
 * The HID event to remove.
 */
- (void)removeEvent:(HIDEvent *)event;

/*!
 * @method removeAllEvents
 *
 * @abstract
 * Removes all child HID events from the HIDEvent object.
 */
- (void)removeAllEvents;

/*!
 * @method conformsToEventType
 *
 * @abstract
 * Iterates through the event and its children to see if the event conforms to
 * the provided event type.
 *
 * @param type
 * The desired event type.
 *
 * @result
 * Returns true if the event conforms to the provided type.
 */
- (BOOL)conformsToEventType:(IOHIDEventType)type;

/*!
 * @property timestamp
 *
 * @abstract
 * The timestamp of the event in mach_absolute_time().
 */
@property uint64_t timestamp;

/*!
 * @property senderID
 *
 * @abstract
 * The sender ID of the event.
 */
@property (readonly) uint64_t senderID;

/*!
 * @property type
 *
 * @abstract
 * The event type.
 */
@property (readonly) IOHIDEventType type;

/*!
 * @property options
 *
 * @abstract
 * The event options. Options are defined in <IOKit/hid/IOHIDKeys.h>
 */
@property uint32_t options;

/*!
 * @property parent
 *
 * @abstract
 * The parent event (if any).
 */
@property (readonly, nullable) HIDEvent *parent;

/*!
 * @property children
 *
 * @abstract
 * An array of child HIDEvents (if any).
 */
@property (readonly, nullable) NSArray<HIDEvent *> *children;

@end

NS_ASSUME_NONNULL_END

#endif /* HIDEvent_h */
