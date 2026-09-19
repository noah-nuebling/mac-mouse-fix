
// HIDEvent+HIDEventDesc.h
// HID


#import <Foundation/Foundation.h>
#import /* <HID/HIDEventFields.h> */ "HIDEventFields.h"
#import "HIDEvent.h" /* <HID/HIDEvent.h> */

NS_ASSUME_NONNULL_BEGIN

/*!
 * @typedef HIDEventFieldInfoBlock
 *
 * @abstract
 * The type block used for enumerateFieldsWithBlock block.
 */
typedef void (^HIDEventFieldInfoBlock) (HIDEventFieldInfo *eventField);

@interface HIDEvent (HIDEventDesc)

/*!
 * @method enumerateFieldsWithBlock
 *
 * @abstract
 * enumerates event fields. Block provided as parameter is
 * called with HIDEventFieldInfo* argument describing each
 * field type
 *
 * @param block
 * Block which will be called for each event field
 */
-(void) enumerateFieldsWithBlock:(HIDEventFieldInfoBlock) block;

@end

NS_ASSUME_NONNULL_END
