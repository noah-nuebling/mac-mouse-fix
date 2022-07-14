//
//  IOHIDAccelerationTable.cpp
//  IOHIDFamily
//
//  Created by YG on 10/29/15.
//
//

#include <CoreFoundation/CoreFoundation.h>
#include "IOHIDAccelerationTable.hpp"
#include <IOKit/IOTypes.h>
#include "IOHIDAccelerationTable.hpp"
#include <iomanip>

template<>
IOFixed ACCEL_TABLE_ENTRY::acceleration<IOFixed> () const {
  return OSReadBigInt32(&accel_, 0);
}

template<>
double ACCEL_TABLE_ENTRY::acceleration<double> () const {
  return FIXED_TO_DOUBLE(acceleration<IOFixed>());
}

uint32_t ACCEL_TABLE_ENTRY::count () const {
  return OSReadBigInt16(&count_, 0);
}

template<>
IOFixed ACCEL_TABLE_ENTRY::x<IOFixed> (unsigned int index) const {
  return   OSReadBigInt32(&points_[index][0], 0);
}

template<>
double ACCEL_TABLE_ENTRY::x<double>(unsigned int index) const {
  return FIXED_TO_DOUBLE(x<IOFixed>(index));
}

template<>
IOFixed ACCEL_TABLE_ENTRY::y (unsigned int index) const {
  return  OSReadBigInt32(&points_[index][1], 0);
}

template<>
double ACCEL_TABLE_ENTRY::y (unsigned int index) const {
  return FIXED_TO_DOUBLE(y<IOFixed>(index));
}

ACCEL_POINT ACCEL_TABLE_ENTRY::point (unsigned int index) const {
  ACCEL_POINT result;
  result.x = x<double>(index);
  result.y = y<double>(index);
  return result;
}

uint32_t ACCEL_TABLE_ENTRY::length () const {
  return count() * sizeof(uint32_t) * 2 + sizeof (uint32_t) + sizeof(uint16_t) ;
}

inline std::ostream & operator<<(std::ostream &os, const ACCEL_TABLE_ENTRY& e) {
  os << " Entry: " <<  std::setw(16) << std::hex << (void*)&e << "\n";
  os << "    acceleration: " <<  e.acceleration<double>() << "\n";
  for (uint32_t i = 0 ; i < e.count(); i++) {
      os << "    x: " << e.x<double>(i) << "(" << std::hex << e.x<IOFixed>(i) << ")\n" <<
            "    y: " << e.y<double>(i) << "(" << std::hex << e.y<IOFixed>(i) << ")\n";
  }
  return os;
}


template<>
IOFixed ACCEL_TABLE::scale () const {
  return OSReadBigInt32(&scale_, 0);
}

template<>
double ACCEL_TABLE::scale () const {
  return FIXED_TO_DOUBLE(scale<IOFixed>());
}

uint32_t ACCEL_TABLE::count () const {
  return OSReadBigInt16(&count_, 0);
}

uint32_t ACCEL_TABLE::signature() const {
  return signature_;
}

const ACCEL_TABLE_ENTRY * ACCEL_TABLE::entry (int index) const {
  const ACCEL_TABLE_ENTRY *current = &entry_;
  for (int i = 1 ; i <= index; i++) {
    current = (ACCEL_TABLE_ENTRY*)((uint8_t*)current + current->length());
  }
  return current;
}

std::ostream & operator<<(std::ostream &os, const ACCEL_TABLE& t) {
  os << " Table: " << std::hex << std::setw(16) << std::setfill('0') << (void*)&t << "\n";
  os << "   scale: " << t.scale<double>() << "\n";
  for (uint32_t i = 0 ; i < t.count(); i++) {
      const ACCEL_TABLE_ENTRY *entry = t.entry(i);
      os << *entry;
  }
  return os;
}

