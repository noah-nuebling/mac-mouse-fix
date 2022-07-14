//
// --------------------------------------------------------------------------
// IOHIDAccelerationTableBridge.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// Create table-based acceleration curves.
/// These can be set on an Apple mouse driver instance using the `kIOHIDPointerAccelerationTableKey`
///
/// Apple's mouse drivers also support parametric acceleration curves, which create a more smooth curve but aren't as flexible when it comes to the shape of the curve. You can simply create a parametric curve by filling out the `MFAppleAccelerationCurveParams` struct.
///
/// Like parametric curves, the table-based curve maps mouse velocity to pointer velocity.
/// Unlike parametric curves, table-based curves are not defined in terms of parameters for mathematical curve but in terms of key points through which the curve passes.
/// These key points are connected with straight lines which make the derivative of the curve discontinuous. This might be detrimental to the feel of the curve.
///
/// This code is complicated and does some bit level stuff because the acceleration tables that Apples used were originally defined as pure data. They apparently just wrote them by hand as a string of bytes which is crazy. Older code parsed this raw string of bytes directly which is also crazy. For newer code they built some CPP structs. But the raw bytes that make up one of those struct instances needs to be a valid legacy table. In fact you could say the structs are just a way to make it easier to read data from the legacy tables. There is no way to construct these structs except from raw bytes.
/// But here we built mechanisms to create struct instances from parameters instead of raw bytes. Then we can cast the struct instances to rawBytes to get a valid legacy table that the Apple Driver can read.
/// That's what `CONSTRUCTABLE_ACCEL_TABLE_ENTRY` and `CONSTRUCTABLE_ACCEL_TABLE` are there for.

#import "IOHIDAccelerationTableBridge.hpp"

#import <Foundation/Foundation.h>
#import <iostream>

#import "IOHIDAccelerationTable.hpp"

#pragma mark - Constructable copies of `ACCEL_TABLE` and `ACCEL_TABLE_ENTRY`
/// `ACCEL_TABLE` and `ACCEL_TABLE_ENTRY` (found in `IOHIDAccelerationTable.cpp`) don't have constructors. As a workaround we created equivalent structs `CONSTRUCTABLE_ACCEL_TABLE` and `CONSTRUCTABLE_ACCEL_TABLE_ENTRY` which generate the same byte-level data layout. We then obtain the desired structs from the constructable ones through type casting.

/// Implementation

struct CONSTRUCTABLE_ACCEL_TABLE_ENTRY {

    /// --- Additions ---
    
    static CONSTRUCTABLE_ACCEL_TABLE_ENTRY *construct(double accel,
                                                      uint16_t count,
                                                      P *points) {
        
        size_t size = sizeof(uint32_t) + sizeof(count) + sizeof(uint32_t[2]) * count; /// Same as `length()`
        CONSTRUCTABLE_ACCEL_TABLE_ENTRY *instance = (CONSTRUCTABLE_ACCEL_TABLE_ENTRY *)malloc(size);
        
        instance->setValues(accel, count, points);
        return instance;
    }
    
    void setValues(double accel,
                   uint16_t count,
                   P *points) {
        
        
        OSWriteBigInt32(&accel_, 0, FloatToFixed(accel));
        OSWriteBigInt16(&count_, 0, count);
        
        /// Convert points
        
        uint32_t rawPoints[count][2];
        for (int i = 0; i < count; i++) {
            int32_t rawX;
            int32_t rawY;
            OSWriteBigInt32(&rawX, 0, FloatToFixed(points[i].x));
            OSWriteBigInt32(&rawY, 0, FloatToFixed(points[i].y));
            rawPoints[i][0] = rawX;
            rawPoints[i][1] = rawY;
        }

        memcpy(points_, rawPoints, sizeof(uint32_t[2]) * count);
    }
    
    ACCEL_TABLE_ENTRY *cast() const {
        return (ACCEL_TABLE_ENTRY *)this;
    }
    
private:
    
    uint32_t accel_;
    uint16_t count_;
    uint32_t points_[1][2];
    
} __attribute__ ((packed));


struct CONSTRUCTABLE_ACCEL_TABLE {
    
    /// --- Additions ---
    
    static CONSTRUCTABLE_ACCEL_TABLE *construct(ACCEL_TABLE_ENTRY *entry) {
        
        size_t size = sizeof(scale_) + sizeof(signature_) + sizeof(count_) + entry->length();
        
        CONSTRUCTABLE_ACCEL_TABLE *instance = (CONSTRUCTABLE_ACCEL_TABLE *)malloc(size);
        instance->setValuesWithEntry(entry);
        
        return instance;
    }
    
    void setValuesWithEntry(ACCEL_TABLE_ENTRY *entry) {
        
        OSWriteBigInt32(&scale_, 0, FloatToFixed(1.0)); /// Seems to be totally unused by `IOHIDTableAcceleration`
        signature_ = APPLE_ACCELERATION_DEFAULT_TABLE_SIGNATURE;
        OSWriteBigInt16(&count_, 0, 1); /// There can be more entries in memory after the first one but it's difficult to construct and we don't need it, so just use a single entry.
        memcpy(&entry_, entry, entry->length());
    }
    
    ACCEL_TABLE *cast() const {
        return (ACCEL_TABLE *)this;
    }
    
    size_t length() const {
        /// Size in bytes. Analog to ACCEL_TABLE_ENTRY::length(). Assumes that there is only 1 entry.
        
        return sizeof(scale_) + sizeof(signature_) + sizeof(count_) + entry_.length();
    }
    
private:
    
    uint32_t scale_;
    uint32_t signature_;
    uint16_t count_;
    ACCEL_TABLE_ENTRY entry_;
    
} __attribute__ ((packed));


#pragma mark - Interface

CFDataRef createAccelerationTableWithArray(NSArray/**<<NSNumber *> *>*/ *points, double accelIndex) {
    
    /// `points` is supposed to have type NSArray<NSArray<NSNumber *> *> *, where the inner array represents a points -> Has two float values representing x and y.
    
    /// Convert to C
    
    P cPoints[points.count];
    
    for (int i = 0; i < points.count; i++) {
        NSArray *p = [points objectAtIndex:i];
        double x = [[p objectAtIndex:0] doubleValue];
        double y = [[p objectAtIndex:1] doubleValue];
        cPoints[i] = { .x = x, .y = y };
    }
    
    /// Call core function
    return createAccelerationTableWithPoints(cPoints, points.count, accelIndex);
}

CFDataRef createAccelerationTableWithPoints(P *points, uint16_t pointCount, double accelIndex) {
    
    /// Create table
    
    ACCEL_TABLE_ENTRY *entry = CONSTRUCTABLE_ACCEL_TABLE_ENTRY::construct(accelIndex,
                                                                          pointCount,
                                                                          points)->cast();
    
    CONSTRUCTABLE_ACCEL_TABLE *table_const = CONSTRUCTABLE_ACCEL_TABLE::construct(entry);
    size_t tableSize = table_const->length();
    ACCEL_TABLE *table = table_const->cast();
    
    /// Release memory
    free(entry);
    
    /// Create data
    CFDataRef data = CFDataCreate(kCFAllocatorDefault, (UInt8 *)table, tableSize);
    
    /// Release other memory
    free(table);
    
    /// Return data
    return data;
}

CFDataRef copyDefaultAccelerationTable() {
    
    /// Copied from `IOHIDPointerScrollFilter.cpp`
    static const UInt8 defaultAccelTable[] = {
        0x00, 0x00, 0x80, 0x00,
        0x40, 0x32, 0x30, 0x30, 0x00, 0x02, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
        0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00,
        0x00, 0x09, 0x00, 0x00, 0x71, 0x3B, 0x00, 0x00,
        0x60, 0x00, 0x00, 0x04, 0x4E, 0xC5, 0x00, 0x10,
        0x80, 0x00, 0x00, 0x0C, 0x00, 0x00, 0x00, 0x5F,
        0x00, 0x00, 0x00, 0x16, 0xEC, 0x4F, 0x00, 0x8B,
        0x00, 0x00, 0x00, 0x1D, 0x3B, 0x14, 0x00, 0x94,
        0x80, 0x00, 0x00, 0x22, 0x76, 0x27, 0x00, 0x96,
        0x00, 0x00, 0x00, 0x24, 0x62, 0x76, 0x00, 0x96,
        0x00, 0x00, 0x00, 0x26, 0x00, 0x00, 0x00, 0x96,
        0x00, 0x00, 0x00, 0x28, 0x00, 0x00, 0x00, 0x96,
        0x00, 0x00
    };
    
    CFDataRef data = CFDataCreate(kCFAllocatorDefault, defaultAccelTable, sizeof(defaultAccelTable));
    
    return data;
}


#pragma mark - Debug

void printAccelerationTable(CFDataRef tableData) {
    
    ACCEL_TABLE *table_reconst = (ACCEL_TABLE *)CFDataGetBytePtr(tableData);
    
    std::string pointsString = "";
    for (int j; j < table_reconst->count(); j++) {
        const ACCEL_TABLE_ENTRY *entry_reconst = table_reconst->entry(j);
        for (int i = 0; i < entry_reconst->count(); i++) {
            ACCEL_POINT p = entry_reconst->point(i);
            pointsString += "(" + std::to_string(p.x) + ", " + std::to_string(p.y) + "), ";
        }
        pointsString += "\n";
    }
    std::cout << "Reconstructed acc table from data: " << *table_reconst << " points_reconst: " << pointsString << std::endl;
}
