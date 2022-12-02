/*
 *    FanControl
 *
 *    Copyright (c) 2006-2012 Hendrik Holtmann
 *
 *    Sensor.h - MacBook(Pro) FanControl application
 *
 *    This program is free software; you can redistribute it and/or modify
 *    it under the terms of the GNU General Public License as published by
 *    the Free Software Foundation; either version 2 of the License, or
 *    (at your option) any later version.
 *
 *    This program is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    GNU General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with this program; if not, write to the Free Software
 *    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#import <Foundation/Foundation.h>

#import <IOKit/hidsystem/IOHIDEventSystemClient.h>
#import <IOKit/hidsystem/IOHIDServiceClient.h>

// https://opensource.apple.com/source/IOHIDFamily/IOHIDFamily-1035.70.7/IOHIDFamily/AppleHIDUsageTables.h.auto.html
#define kHIDPage_AppleVendor    0xff00
#define kHIDUsage_AppleVendor_TemperatureSensor    0x0005

// https://opensource.apple.com/source/IOHIDFamily/IOHIDFamily-1035.70.7/IOHIDFamily/IOHIDEventTypes.h.auto.html
#ifdef __LP64__
typedef double IOHIDFloat;
#else
typedef float IOHIDFloat;
#endif

// https://opensource.apple.com/source/IOHIDFamily/IOHIDFamily-1035.70.7/IOHIDFamily/IOHIDEventTypes.h.auto.html
#define IOHIDEventFieldBase(type) (type << 16)
#define kIOHIDEventTypeTemperature  15


typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;

IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef);
void IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef, CFDictionaryRef);
IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef, int64_t, int32_t, int64_t);
IOHIDFloat IOHIDEventGetFloatValue(IOHIDEventRef event, uint32_t field);

@interface IOKitSensor : NSObject {
}

+ (float) getSOCTemperature;

@end
